{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.atelier.services.emojibot;
in
{
  options.atelier.services.emojibot = {
    enable = lib.mkEnableOption "Emojibot Slack emoji management service";

    domain = lib.mkOption {
      type = lib.types.str;
      description = "Domain to serve emojibot on";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3002;
      description = "Port to run emojibot on";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/emojibot";
      description = "Directory to store emojibot data";
    };

    secretsFile = lib.mkOption {
      type = lib.types.path;
      description = ''
        Path to secrets file containing:
        - SLACK_SIGNING_SECRET
        - SLACK_BOT_TOKEN
        - SLACK_APP_TOKEN
        - SLACK_BOT_USER_TOKEN (get from browser, see emojibot README)
        - SLACK_COOKIE (get from browser, see emojibot README)
        - SLACK_WORKSPACE (e.g. "myworkspace" for myworkspace.slack.com)
        - SLACK_CHANNEL (channel ID where emojis are posted)
        - ADMINS (comma-separated list of slack user IDs)
      '';
    };

    repository = lib.mkOption {
      type = lib.types.str;
      default = "https://github.com/taciturnaxolotl/emojibot.git";
      description = "Git repository URL (optional, for auto-deployment)";
    };

    autoUpdate = lib.mkEnableOption "Automatically git pull on service restart";
  };

  config = lib.mkIf cfg.enable {
    users.groups.services = { };

    users.users.emojibot = {
      isSystemUser = true;
      group = "emojibot";
      extraGroups = [ "services" ];
      home = cfg.dataDir;
      createHome = true;
      shell = pkgs.bash;
    };

    users.groups.emojibot = { };

    security.sudo.extraRules = [
      {
        users = [ "emojibot" ];
        commands = [
          {
            command = "/run/current-system/sw/bin/systemctl restart emojibot.service";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];

    systemd.services.emojibot = {
      description = "Emojibot Slack emoji management service";
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
        User = "emojibot";
        Group = "emojibot";
        EnvironmentFile = cfg.secretsFile;
        Environment = [
          "NODE_ENV=production"
          "PORT=${toString cfg.port}"
        ];
        ExecStart = "${pkgs.bash}/bin/bash -c 'cd ${cfg.dataDir}/app && ${pkgs.unstable.bun}/bin/bun run src/index.ts'";
        Restart = "always";
        RestartSec = "10s";
      };

      serviceConfig.ExecStartPre = [
        "+${pkgs.writeShellScript "emojibot-setup" ''
          mkdir -p ${cfg.dataDir}/app
          chown -R emojibot:services ${cfg.dataDir}
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
