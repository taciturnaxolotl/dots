# CedarLogic - Web-based circuit simulator
#
# Custom module (not mkService) because:
# - App lives in web/ subdirectory of the repo
# - Needs a Vite build step before serving
# - Multi-port: API (3000), Hocuspocus WS (3001), Cursor WS (3002)
# - Caddy needs path-based routing to different backends

{ config, lib, pkgs, ... }:

let
  cfg = config.atelier.services.cedarlogic;
  appDir = "${cfg.dataDir}/app";
  webDir = "${appDir}/web";
in
{
  options.atelier.services.cedarlogic = {
    enable = lib.mkEnableOption "CedarLogic circuit simulator";

    domain = lib.mkOption {
      type = lib.types.str;
      description = "Domain to serve CedarLogic on";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/cedarlogic";
      description = "Directory to store CedarLogic data";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3100;
      description = "Port for the HTTP API server";
    };

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

    secretsFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to secrets file (GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET, JWT_SECRET)";
    };

    deploy = {
      repository = lib.mkOption {
        type = lib.types.str;
        default = "https://github.com/taciturnaxolotl/CedarLogic";
        description = "Git repository URL";
      };

      branch = lib.mkOption {
        type = lib.types.str;
        default = "web";
        description = "Git branch to deploy";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # User and group
    users.groups.services = {};

    users.users.cedarlogic = {
      isSystemUser = true;
      group = "cedarlogic";
      extraGroups = [ "services" ];
      home = cfg.dataDir;
      createHome = true;
      shell = pkgs.bash;
    };

    users.groups.cedarlogic = {};

    # Caddy needs to read static files from the dist directory
    users.users.caddy.extraGroups = [ "cedarlogic" "services" ];

    # Allow cedarlogic user to restart its own service (for SSH deploys)
    security.sudo.extraRules = [
      {
        users = [ "cedarlogic" ];
        commands = [
          {
            command = "/run/current-system/sw/bin/systemctl restart cedarlogic.service";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];

    # Systemd service
    systemd.services.cedarlogic = {
      description = "CedarLogic circuit simulator";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      path = [ pkgs.git pkgs.openssh pkgs.unstable.bun ];

      preStart = ''
        set -e

        # Clone if not present
        if [ ! -d ${appDir}/.git ]; then
          ${pkgs.git}/bin/git clone -b ${cfg.deploy.branch} ${cfg.deploy.repository} ${appDir}
        fi

        cd ${webDir}

        # Install dependencies
        if [ -f package.json ]; then
          ${pkgs.unstable.bun}/bin/bun install
        fi

        # Generate gate definitions from XML
        ${pkgs.unstable.bun}/bin/bun run parse-gates

        # Build client (Vite)
        ${pkgs.unstable.bun}/bin/bun run build
      '';

      serviceConfig = {
        Type = "exec";
        User = "cedarlogic";
        Group = "cedarlogic";
        # Don't set WorkingDirectory — preStart needs to run before
        # the repo is cloned, and systemd applies it to all stages.
        # Instead, ExecStart cd's into webDir.
        EnvironmentFile = lib.mkIf (cfg.secretsFile != null) cfg.secretsFile;
        Environment = [
          "NODE_ENV=production"
          "PORT=${toString cfg.port}"
          "WS_PORT=${toString cfg.wsPort}"
          "CURSOR_PORT=${toString cfg.cursorPort}"
          "DATABASE_PATH=${cfg.dataDir}/data/cedarlogic.db"
          "GOOGLE_REDIRECT_URI=https://${cfg.domain}/auth/google/callback"
        ];
        ExecStart = "${pkgs.bash}/bin/bash -c 'cd ${webDir} && exec ${pkgs.unstable.bun}/bin/bun run src/server/index.ts'";
        Restart = "on-failure";
        RestartSec = "10s";
        TimeoutStartSec = "120s";

        StateDirectory = "cedarlogic";
        StateDirectoryMode = "0755";

        UMask = "0022";
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
      };

      serviceConfig.ExecStartPre = [
        "!${pkgs.writeShellScript "cedarlogic-setup" ''
          mkdir -p ${webDir}
          mkdir -p ${cfg.dataDir}/data
          chown -R cedarlogic:services ${cfg.dataDir}
          chmod -R g+rwX ${cfg.dataDir}
        ''}"
      ];
    };

    systemd.tmpfiles.rules = [
      "d ${appDir} 0755 cedarlogic services -"
      "d ${cfg.dataDir}/data 0755 cedarlogic services -"
    ];

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

    # Backup config
    atelier.backup.services.cedarlogic = {
      paths = [ "${cfg.dataDir}/data" ];
      exclude = [ "*.log" ];
      preBackup = "systemctl stop cedarlogic";
      postBackup = "systemctl start cedarlogic";
    };
  };
}
