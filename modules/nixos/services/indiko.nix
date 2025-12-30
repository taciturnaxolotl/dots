{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.atelier.services.indiko;
in
{
  options.atelier.services.indiko = {
    enable = lib.mkEnableOption "Indiko IndieAuth/OAuth2 server";

    domain = lib.mkOption {
      type = lib.types.str;
      description = "Domain to serve Indiko on";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3003;
      description = "Port to run Indiko on";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/indiko";
      description = "Directory to store Indiko data";
    };

    secretsFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Path to secrets file (optional).
        If you need additional environment variables, define them here.
      '';
    };

    repository = lib.mkOption {
      type = lib.types.str;
      default = "https://github.com/taciturnaxolotl/indiko.git";
      description = "Git repository URL (optional, for auto-deployment)";
    };

    autoUpdate = lib.mkEnableOption "Automatically git pull on service restart";

    backup = {
      enable = lib.mkEnableOption "Enable backups for indiko" // { default = true; };

      paths = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ cfg.dataDir ];
        description = "Paths to back up";
      };

      exclude = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "*.log" "app/.git" "app/node_modules" ];
        description = "Patterns to exclude from backup";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.services = { };

    users.users.indiko = {
      isSystemUser = true;
      group = "indiko";
      extraGroups = [ "services" ];
      home = cfg.dataDir;
      createHome = true;
      shell = pkgs.bash;
    };

    users.groups.indiko = { };

    security.sudo.extraRules = [
      {
        users = [ "indiko" ];
        commands = [
          {
            command = "/run/current-system/sw/bin/systemctl restart indiko.service";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];

    systemd.services.indiko = {
      description = "Indiko IndieAuth/OAuth2 server";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      path = [ pkgs.git ];

      preStart = ''
        if [ ! -d ${cfg.dataDir}/app/.git ]; then
          ${pkgs.git}/bin/git clone ${cfg.repository} ${cfg.dataDir}/app
        fi
        
        cd ${cfg.dataDir}/app
      '' + lib.optionalString cfg.autoUpdate ''
        ${pkgs.git}/bin/git pull
      '' + ''
        
        if [ ! -f src/index.ts ]; then
          echo "No code found at ${cfg.dataDir}/app/src/index.ts"
          exit 1
        fi
        
        echo "Installing dependencies..."
        ${pkgs.unstable.bun}/bin/bun install
      '';

      serviceConfig = {
        Type = "simple";
        User = "indiko";
        Group = "indiko";
        EnvironmentFile = lib.mkIf (cfg.secretsFile != null) cfg.secretsFile;
        Environment = [
          "NODE_ENV=production"
          "PORT=${toString cfg.port}"
          "ORIGIN=https://${cfg.domain}"
          "RP_ID=${cfg.domain}"
        ];
        ExecStart = "${pkgs.bash}/bin/bash -c 'cd ${cfg.dataDir}/app && ${pkgs.unstable.bun}/bin/bun run src/index.ts'";
        Restart = "always";
        RestartSec = "10s";
      };

      serviceConfig.ExecStartPre = [
        "+${pkgs.writeShellScript "indiko-setup" ''
          mkdir -p ${cfg.dataDir}/app
          chown -R indiko:services ${cfg.dataDir}
          chmod -R g+rwX ${cfg.dataDir}
        ''}"
      ];
    };

    services.caddy.virtualHosts.${cfg.domain} = {
      extraConfig = ''
        tls {
          dns cloudflare {env.CLOUDFLARE_API_TOKEN}
        }

        # Rate limiting for auth endpoints
        handle /auth/* {
          rate_limit {
            zone auth_limit {
              key {http.request.remote_ip}
              events 10
              window 1m
            }
          }
          reverse_proxy localhost:${toString cfg.port}
        }

        # Rate limiting for API endpoints
        handle /api/* {
          rate_limit {
            zone api_limit {
              key {http.request.remote_ip}
              events 30
              window 1m
            }
          }
          reverse_proxy localhost:${toString cfg.port}
        }

        # General rate limiting for all other routes
        handle {
          rate_limit {
            zone general_limit {
              key {http.request.remote_ip}
              events 60
              window 1m
            }
          }
          reverse_proxy localhost:${toString cfg.port}
        }
      '';
    };

    # Register backup configuration  
    atelier.backup.services.indiko = lib.mkIf cfg.backup.enable {
      inherit (cfg.backup) paths exclude;
      # Has SQLite database for sessions/tokens
      preBackup = "systemctl stop indiko";
      postBackup = "systemctl start indiko";
    };
  };
}
