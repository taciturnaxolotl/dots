{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.atelier.services.hn-alerts;
in
{
  options.atelier.services.hn-alerts = {
    enable = lib.mkEnableOption "HN Alerts Hacker News monitoring service";

    domain = lib.mkOption {
      type = lib.types.str;
      description = "Domain to serve hn-alerts on";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3001;
      description = "Port to run hn-alerts on";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/hn-alerts";
      description = "Directory to store hn-alerts data";
    };

    secretsFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to secrets file containing SLACK_BOT_TOKEN, SLACK_SIGNING_SECRET, SLACK_CHANNEL, SENTRY_DSN, DATABASE_URL";
    };

    repository = lib.mkOption {
      type = lib.types.str;
      default = "https://github.com/taciturnaxolotl/hn-alerts.git";
      description = "Git repository URL (optional, for auto-deployment)";
    };

    autoUpdate = lib.mkEnableOption "Automatically git pull on service restart";
  };

  config = lib.mkIf cfg.enable {
    users.groups.services = { };

    users.users.hn-alerts = {
      isSystemUser = true;
      group = "hn-alerts";
      extraGroups = [ "services" ];
      home = cfg.dataDir;
      createHome = true;
      shell = pkgs.bash;
    };

    users.groups.hn-alerts = { };

    security.sudo.extraRules = [
      {
        users = [ "hn-alerts" ];
        commands = [
          {
            command = "/run/current-system/sw/bin/systemctl restart hn-alerts.service";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];

    systemd.services.hn-alerts = {
      description = "HN Alerts Hacker News monitoring service";
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
        
        echo "Initializing database..."
        ${pkgs.unstable.bun}/bin/bun run db:push
      '';

      serviceConfig = {
        Type = "simple";
        User = "hn-alerts";
        Group = "hn-alerts";
        EnvironmentFile = cfg.secretsFile;
        Environment = [
          "NODE_ENV=production"
          "PORT=${toString cfg.port}"
        ];
        ExecStart = "${pkgs.bash}/bin/bash -c 'cd ${cfg.dataDir}/app && ${pkgs.unstable.bun}/bin/bun start'";
        Restart = "always";
        RestartSec = "10s";
      };
    };

    services.caddy.virtualHosts.${cfg.domain} = {
      extraConfig = ''
        tls {
          dns cloudflare {env.CLOUDFLARE_API_TOKEN}
        }

        reverse_proxy localhost:${toString cfg.port}
      '';
    };
  };
}
