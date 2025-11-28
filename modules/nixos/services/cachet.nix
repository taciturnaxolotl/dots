{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.atelier.services.cachet;
in
{
  options.atelier.services.cachet = {
    enable = lib.mkEnableOption "Cachet Slack emoji/profile cache";

    domain = lib.mkOption {
      type = lib.types.str;
      description = "Domain to serve cachet on";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3000;
      description = "Port to run cachet on";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/cachet";
      description = "Directory to store cachet data";
    };

    secretsFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to secrets file containing SLACK_TOKEN, SLACK_SIGNING_SECRET, BEARER_TOKEN";
    };

    repository = lib.mkOption {
      type = lib.types.str;
      default = "https://github.com/taciturnaxolotl/cachet.git";
      description = "Git repository URL (optional, for auto-deployment)";
    };

    autoUpdate = lib.mkEnableOption "Automatically git pull on service restart";

    webhook = {
      enable = lib.mkEnableOption "Enable webhook endpoint for triggering service restart";

      path = lib.mkOption {
        type = lib.types.str;
        default = "/webhook/restart";
        description = "URL path for the webhook endpoint";
      };

      secretFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Path to file containing webhook secret token";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.services = { };

    users.users.cachet = {
      isSystemUser = true;
      group = "cachet";
      extraGroups = [ "services" ];
      home = cfg.dataDir;
      createHome = true;
    };

    users.groups.cachet = { };

    systemd.services.cachet-webhook = lib.mkIf cfg.webhook.enable {
      description = "Cachet webhook listener";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      script = let
        webhookScript = pkgs.writeShellScript "cachet-webhook" ''
          SECRET=""
          ${lib.optionalString (cfg.webhook.secretFile != null) ''
            SECRET=$(cat "${cfg.webhook.secretFile}")
          ''}

          while IFS= read -r line; do
            # Parse the request line
            if [[ "$line" =~ ^GET.*token=([^\ \&]+) ]]; then
              TOKEN="''${BASH_REMATCH[1]}"
              if [ "$TOKEN" = "$SECRET" ]; then
                echo -e "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\nRestarting cachet service..."
                ${pkgs.systemd}/bin/systemctl restart cachet &
              else
                echo -e "HTTP/1.1 403 Forbidden\r\nContent-Type: text/plain\r\n\r\nInvalid token"
              fi
            else
              echo -e "HTTP/1.1 400 Bad Request\r\nContent-Type: text/plain\r\n\r\nBad request"
            fi
            break
          done
        '';
      in ''
        while true; do
          ${pkgs.netcat}/bin/nc -l -p 9000 -c "${webhookScript}"
        done
      '';

      serviceConfig = {
        Type = "simple";
        Restart = "always";
        RestartSec = "5s";
      };
    };

    systemd.services.cachet = {
      description = "Cachet Slack emoji/profile cache";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      preStart = ''
        mkdir -p ${cfg.dataDir}/data
        mkdir -p ${cfg.dataDir}/app
        chown -R cachet:services ${cfg.dataDir}
        chmod -R g+rwX ${cfg.dataDir}
      '' + lib.optionalString cfg.autoUpdate ''
        if [ ! -d ${cfg.dataDir}/app/.git ]; then
          ${pkgs.git}/bin/git clone ${cfg.repository} ${cfg.dataDir}/app
        else
          cd ${cfg.dataDir}/app && ${pkgs.git}/bin/git pull
        fi
      '';

      serviceConfig = {
        Type = "simple";
        User = "cachet";
        Group = "cachet";
        WorkingDirectory = "${cfg.dataDir}/app";
        EnvironmentFile = cfg.secretsFile;
        Environment = [
          "NODE_ENV=production"
          "PORT=${toString cfg.port}"
          "DATABASE_PATH=${cfg.dataDir}/data/cachet.db"
        ];
        ExecStart = "${pkgs.unstable.bun}/bin/bun run src/index.ts";
        Restart = "always";
        RestartSec = "10s";
      };
    };

    services.caddy.virtualHosts.${cfg.domain} = {
      extraConfig = ''
        tls {
          dns cloudflare {env.CLOUDFLARE_API_TOKEN}
        }

        ${lib.optionalString cfg.webhook.enable ''
        handle ${cfg.webhook.path} {
          reverse_proxy localhost:9000
        }
        ''}

        reverse_proxy localhost:${toString cfg.port}
      '';
    };
  };
}
