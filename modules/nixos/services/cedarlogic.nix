# CedarLogic - Web-based circuit simulator
#
# Multi-port service: API, Hocuspocus WS, Cursor WS
# App lives in web/ subdirectory, needs Vite build step

{ config, lib, pkgs, ... }:

let
  mkService = import ../../lib/mkService.nix;
  cfg = config.atelier.services.cedarlogic;
  webDir = "${cfg.dataDir}/app/web";

  baseModule = mkService {
    name = "cedarlogic";
    description = "CedarLogic circuit simulator";
    defaultPort = 3100;
    runtime = "custom";
    startCommand = "cd ${webDir} && exec ${pkgs.unstable.bun}/bin/bun run src/server/index.ts";

    extraOptions = {
      wsPort = lib.mkOption {
        type = lib.types.port;
        default = 3101;
        description = "Port for the Hocuspocus WebSocket server";
      };

      cursorPort = lib.mkOption {
        type = lib.types.port;
        default = 3102;
        description = "Port for the cursor relay WebSocket server";
      };

      branch = lib.mkOption {
        type = lib.types.str;
        default = "web";
        description = "Git branch to clone";
      };
    };

    extraConfig = cfg: {
      atelier.services.cedarlogic.environment = {
        WS_PORT = toString cfg.wsPort;
        CURSOR_PORT = toString cfg.cursorPort;
        DATABASE_PATH = "${cfg.dataDir}/data/cedarlogic.db";
        GOOGLE_REDIRECT_URI = "https://${cfg.domain}/auth/google/callback";
      };

      # Disable default caddy — we need path-based routing to 3 backends
      atelier.services.cedarlogic.caddy.enable = false;

      # Data declarations for automatic backup
      atelier.services.cedarlogic.data = {
        sqlite = "${cfg.dataDir}/data/cedarlogic.db";
      };

      # Caddy needs to read static files from the dist directory
      users.users.caddy.extraGroups = [ "cedarlogic" "services" ];

      # Longer timeout for Vite build
      systemd.services.cedarlogic.serviceConfig = {
        TimeoutStartSec = lib.mkForce "120s";
        UMask = "0022";
      };

      # Build step: install deps + parse gates + vite build
      systemd.services.cedarlogic.preStart = lib.mkAfter ''
        cd ${webDir}

        if [ -f package.json ]; then
          ${pkgs.unstable.bun}/bin/bun install
        fi

        # Generate gate definitions from XML
        ${pkgs.unstable.bun}/bin/bun run parse-gates

        # Build client (Vite)
        ${pkgs.unstable.bun}/bin/bun run build
      '';

      # Caddy - path-based routing to 3 backends + static file serving
      services.caddy.virtualHosts.${cfg.domain} = {
        extraConfig = ''
          tls {
            dns cloudflare {env.CLOUDFLARE_API_TOKEN}
          }
          header {
            Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
          }

          # Hocuspocus WebSocket (Yjs collaboration)
          handle /ws {
            reverse_proxy localhost:${toString cfg.wsPort}
          }

          # Cursor relay WebSocket
          handle /cursor-ws {
            reverse_proxy localhost:${toString cfg.cursorPort}
          }

          # API and auth routes
          handle /api/* {
            reverse_proxy localhost:${toString cfg.port}
          }
          handle /auth/* {
            reverse_proxy localhost:${toString cfg.port}
          }

          # Static files (Vite build output + WASM)
          handle {
            root * ${webDir}/dist
            try_files {path} /index.html
            file_server
          }
        '';
      };
    };
  };
in
{
  imports = [ baseModule ];

  # Override the initial clone to use the non-default branch
  config = lib.mkIf cfg.enable {
    systemd.services.cedarlogic.preStart = lib.mkBefore ''
      set -e
      if [ ! -d ${cfg.dataDir}/app/.git ]; then
        ${pkgs.git}/bin/git clone -b ${cfg.branch} ${cfg.repository} ${cfg.dataDir}/app
      fi
    '';
  };
}
