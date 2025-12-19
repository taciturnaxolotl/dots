{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.atelier.services.l4;
in
{
  options.atelier.services.l4 = {
    enable = lib.mkEnableOption "L4 Image CDN service";

    domain = lib.mkOption {
      type = lib.types.str;
      description = "Domain to serve L4 on";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3004;
      description = "Port to run L4 on";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/l4";
      description = "Directory to store L4 data";
    };

    secretsFile = lib.mkOption {
      type = lib.types.path;
      description = ''
        Path to secrets file containing:
        - R2_ACCOUNT_ID
        - R2_ACCESS_KEY_ID
        - R2_SECRET_ACCESS_KEY
        - R2_BUCKET
        - R2_PUBLIC_URL
        - SLACK_BOT_TOKEN
        - SLACK_SIGNING_SECRET
        - ALLOWED_CHANNELS (optional, comma-separated channel IDs)
      '';
    };

    repository = lib.mkOption {
      type = lib.types.str;
      default = "https://github.com/taciturnaxolotl/l4.git";
      description = "Git repository URL (optional, for auto-deployment)";
    };

    autoUpdate = lib.mkEnableOption "Automatically git pull on service restart";
  };

  config = lib.mkIf cfg.enable {
    users.groups.services = { };

    users.users.l4 = {
      isSystemUser = true;
      group = "l4";
      extraGroups = [ "services" ];
      home = cfg.dataDir;
      createHome = true;
      shell = pkgs.bash;
    };

    users.groups.l4 = { };

    security.sudo.extraRules = [
      {
        users = [ "l4" ];
        commands = [
          {
            command = "/run/current-system/sw/bin/systemctl restart l4.service";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];

    systemd.services.l4 = {
      description = "L4 Image CDN - Slack image optimizer and R2 uploader";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      path = [ pkgs.git pkgs.stdenv.cc.cc.lib ];

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
        User = "l4";
        Group = "l4";
        EnvironmentFile = cfg.secretsFile;
        Environment = [
          "NODE_ENV=production"
          "PORT=${toString cfg.port}"
          "PUBLIC_URL=https://${cfg.domain}"
          "LD_LIBRARY_PATH=${pkgs.stdenv.cc.cc.lib}/lib"
        ];
        ExecStart = "${pkgs.bash}/bin/bash -c 'cd ${cfg.dataDir}/app && ${pkgs.unstable.bun}/bin/bun run src/index.ts'";
        Restart = "always";
        RestartSec = "10s";
      };

      serviceConfig.ExecStartPre = [
        "+${pkgs.writeShellScript "l4-setup" ''
          mkdir -p ${cfg.dataDir}/app
          chown -R l4:services ${cfg.dataDir}
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
