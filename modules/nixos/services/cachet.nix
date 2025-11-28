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
  };

  config = lib.mkIf cfg.enable {
    users.groups.services = { };

    users.users.cachet = {
      isSystemUser = true;
      group = "cachet";
      extraGroups = [ "services" ];
      home = cfg.dataDir;
      createHome = true;
      shell = pkgs.bash;
    };

    users.groups.cachet = { };

    security.sudo.extraRules = [
      {
        users = [ "cachet" ];
        commands = [
          {
            command = "/run/current-system/sw/bin/systemctl restart cachet.service";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];

    systemd.services.cachet = {
      description = "Cachet Slack emoji/profile cache";
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
        User = "cachet";
        Group = "cachet";
        EnvironmentFile = cfg.secretsFile;
        Environment = [
          "NODE_ENV=production"
          "PORT=${toString cfg.port}"
          "DATABASE_PATH=${cfg.dataDir}/data/cachet.db"
        ];
        ExecStart = "${pkgs.bash}/bin/bash -c 'cd ${cfg.dataDir}/app && ${pkgs.unstable.bun}/bin/bun run src/index.ts'";
        Restart = "always";
        RestartSec = "10s";
      };

      serviceConfig.ExecStartPre = [
        "+${pkgs.writeShellScript "cachet-setup" ''
          mkdir -p ${cfg.dataDir}/data
          mkdir -p ${cfg.dataDir}/app
          chown -R cachet:services ${cfg.dataDir}
          chmod -R g+rwX ${cfg.dataDir}
        ''}"
      ];
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
