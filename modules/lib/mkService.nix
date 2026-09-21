# mkService - Base service factory for atelier services
#
# Creates a standardized NixOS service module with:
# - Common options (domain, port, dataDir, secrets, etc.)
# - Systemd service with initial git clone for scaffolding
# - Caddy reverse proxy configuration
# - Automatic backup integration via data declarations
#
# Subsequent deployments are handled by per-repo GitHub Actions
# workflows that SSH in as the service user, git pull, and restart.
#
# Usage in a service module:
#   let
#     mkService = import ../../lib/mkService.nix;
#   in
#   mkService {
#     name = "myapp";
#     defaultPort = 3000;
#     extraOptions = { ... };
#     extraConfig = cfg: { ... };
#   }

# This file is a function that takes service parameters and returns a NixOS module
{
  # Service identity
  name,
  description ? "${name} service",
  defaultPort ? 3000,

  # Runtime configuration
  runtime ? "bun", # "bun" | "node" | "custom"
  entryPoint ? "src/index.ts",
  startCommand ? null, # Override the start command entirely

  # Additional options specific to this service
  extraOptions ? { },

  # Additional config when service is enabled
  # Receives cfg (the service config) as argument
  extraConfig ? cfg: { },
}:

# Return a proper NixOS module
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.atelier.services.${name};

  defaultStartCommand =
    {
      bun = "${pkgs.unstable.bun}/bin/bun run ${entryPoint}";
      node = "${pkgs.nodejs_20}/bin/node ${entryPoint}";
    }
    .${runtime} or "";

  finalStartCommand = if startCommand != null then startCommand else defaultStartCommand;

in
{
  options.atelier.services.${name} = {
    enable = lib.mkEnableOption description;

    domain = lib.mkOption {
      type = lib.types.str;
      description = "Domain to serve ${name} on";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = defaultPort;
      description = "Port to run ${name} on";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/${name}";
      description = "Directory to store ${name} data";
    };

    dataDirGroup = lib.mkOption {
      type = lib.types.str;
      default = "services";
      description = ''
        Group owning the data directories. The shared `services` group lets
        every service user (and caddy, if it joins) read every other service's
        data, so set this to the service's own group when something outside the
        service needs access to its files.
      '';
    };

    secretsFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to agenix secrets file";
    };

    # Git repository for initial scaffolding (clone on first start)
    # Subsequent deploys are handled by GitHub Actions workflows
    repository = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Git repository URL — cloned once on first start for scaffolding";
    };

    healthUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Health check URL for monitoring";
    };

    # Internal metadata set by mkService factory — used by services-manifest
    _description = lib.mkOption {
      type = lib.types.str;
      default = description;
      internal = true;
      readOnly = true;
    };

    _runtime = lib.mkOption {
      type = lib.types.str;
      default = runtime;
      internal = true;
      readOnly = true;
    };

    # Every port this service binds. Services with extra listeners override it
    # so the conflict check in services/port-conflicts.nix can see them all.
    _ports = lib.mkOption {
      type = lib.types.listOf lib.types.port;
      default = lib.optionals cfg.enable [ cfg.port ];
      internal = true;
    };

    # Data declarations for automatic backup
    data = {
      sqlite = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Path to SQLite database (will checkpoint WAL for backup)";
        example = "/var/lib/myapp/data/app.db";
      };

      stopForBackup = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to stop the service during backup. Set to false for WAL-mode SQLite services that can be backed up online.";
      };

      stopUnits = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = ''
          Systemd units to stop during backup. Defaults to the service name
          itself, which is only correct when the service ships a single unit
          named after it. Set this for services that split across several units
          (e.g. paperless), otherwise the stop is a no-op against a unit that
          does not exist.
        '';
        example = [
          "paperless-web.service"
          "paperless-consumer.service"
        ];
      };

      postgres = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "PostgreSQL database name (will use pg_dump for backup)";
      };

      files = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Additional file paths to backup (no service interruption)";
        example = [ "/var/lib/myapp/uploads" ];
      };

      exclude = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "*.log"
          "node_modules"
          ".git"
          "cache"
          "tmp"
        ];
        description = "Glob patterns to exclude from backup";
      };
    };

    # Caddy configuration
    caddy = {
      enable = lib.mkEnableOption "Caddy reverse proxy" // {
        default = true;
      };

      upstream = lib.mkOption {
        type = lib.types.str;
        default = "localhost:${toString cfg.port}";
        defaultText = lib.literalExpression ''"localhost:''${toString cfg.port}"'';
        description = ''
          Address Caddy proxies to. Override when the proxy and the service live
          on different machines, so the vhost still comes from here rather than
          being hand-written next to whichever caddy fronts it.
        '';
      };

      hsts = lib.mkEnableOption "Strict-Transport-Security header" // {
        default = true;
      };

      extraConfig = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = "Additional Caddy configuration";
      };

      rateLimit = {
        enable = lib.mkEnableOption "Rate limiting";

        events = lib.mkOption {
          type = lib.types.int;
          default = 60;
          description = "Number of requests allowed per window";
        };

        window = lib.mkOption {
          type = lib.types.str;
          default = "1m";
          description = "Time window for rate limiting";
        };
      };
    };

    # Environment variables (in addition to secretsFile)
    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Additional environment variables";
    };
  }
  // extraOptions;

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        users.groups.services = { };

        users.users.${name} = {
          isSystemUser = true;
          group = name;
          extraGroups = [ "services" ];
          home = cfg.dataDir;
          createHome = false;
          shell = pkgs.bash;
        };

        users.groups.${name} = { };

        # 0770 to match the g+rwX the unit's ExecStartPre applies, so the mode
        # doesn't flip between activation and service start.
        systemd.tmpfiles.rules = [
          "d ${cfg.dataDir} 0755 ${name} ${cfg.dataDirGroup} -"
          "d ${cfg.dataDir}/app 0770 ${name} ${cfg.dataDirGroup} -"
          "d ${cfg.dataDir}/data 0770 ${name} ${cfg.dataDirGroup} -"
        ];

        # Allow service user to manage their own service (for CI/CD deploys)
        security.sudo.extraRules = [
          {
            users = [ name ];
            commands =
              map
                (cmd: {
                  command = "/run/current-system/sw/bin/systemctl ${cmd} ${name}.service";
                  options = [ "NOPASSWD" ];
                })
                [
                  "restart"
                  "stop"
                  "start"
                  "status"
                ];
          }
        ];

        # Systemd service
        systemd.services.${name} = {
          inherit description;
          wantedBy = [ "multi-user.target" ];
          after = [ "network.target" ];
          path = [
            pkgs.git
            pkgs.openssh
          ];

          preStart =
            lib.optionalString (cfg.repository != null) ''
              set -e
              # Clone repository on first start (scaffolding only)
              if [ ! -d ${cfg.dataDir}/app/.git ]; then
                ${pkgs.git}/bin/git clone ${cfg.repository} ${cfg.dataDir}/app
              fi
            ''
            + lib.optionalString (runtime == "bun") ''

              # Install deps only on first clone (no node_modules yet)
              if [ -f ${cfg.dataDir}/app/package.json ] && [ ! -d ${cfg.dataDir}/app/node_modules ]; then
                cd ${cfg.dataDir}/app
                echo "First start: installing dependencies..."
                ${pkgs.unstable.bun}/bin/bun install
              fi
            ''
            + lib.optionalString (runtime == "node") ''

              # Install deps only on first clone (no node_modules yet)
              if [ -f ${cfg.dataDir}/app/package.json ] && [ ! -d ${cfg.dataDir}/app/node_modules ]; then
                cd ${cfg.dataDir}/app
                echo "First start: installing dependencies..."
                ${pkgs.nodejs_20}/bin/npm ci --production
              fi
            '';

          serviceConfig = {
            Type = "exec";
            User = name;
            Group = name;
            WorkingDirectory = "${cfg.dataDir}/app";
            EnvironmentFile = lib.mkIf (cfg.secretsFile != null) cfg.secretsFile;
            Environment = [
              "NODE_ENV=production"
              "PORT=${toString cfg.port}"
            ]
            ++ (lib.mapAttrsToList (k: v: "${k}=${v}") cfg.environment);
            ExecStart = "${pkgs.bash}/bin/bash -c '${finalStartCommand}'";
            Restart = "on-failure";
            RestartSec = "10s";
            TimeoutStartSec = "60s";

            NoNewPrivileges = true;
            ProtectSystem = "strict";
            ReadWritePaths = [ cfg.dataDir ];
            ProtectHome = true;
            PrivateTmp = true;

            # `!` only lifts User=/Group=; the ReadWritePaths sandbox still
            # applies, and this works because tmpfiles made dataDir first.
            ExecStartPre = [
              "!${pkgs.writeShellScript "${name}-setup" ''
                mkdir -p ${cfg.dataDir}/app ${cfg.dataDir}/data
                chown ${name}:${cfg.dataDirGroup} ${cfg.dataDir}
                chown ${name}:${cfg.dataDirGroup} ${cfg.dataDir}/app ${cfg.dataDir}/data
                chmod 0755 ${cfg.dataDir}
                chmod g+rwX ${cfg.dataDir}/app ${cfg.dataDir}/data
              ''}"
            ];
          };
        };

      }

      # Guarding the whole block rather than the attribute value keeps
      # cfg.domain unevaluated when there is no vhost to name.
      (lib.mkIf (cfg.enable && cfg.caddy.enable) {
        services.caddy.virtualHosts.${cfg.domain}.extraConfig = ''
          tls {
            dns cloudflare {env.CLOUDFLARE_API_TOKEN}
          }

          ${lib.optionalString cfg.caddy.hsts ''
            header {
              Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
            }
          ''}

          ${lib.optionalString cfg.caddy.rateLimit.enable ''
            rate_limit {
              zone ${name}_limit {
                key {http.request.remote_ip}
                events ${toString cfg.caddy.rateLimit.events}
                window ${cfg.caddy.rateLimit.window}
              }
            }
          ''}

          ${cfg.caddy.extraConfig}

          reverse_proxy ${cfg.caddy.upstream}
        '';
      })

      # Extra config from the service module
      (extraConfig cfg)
    ]
  );
}
