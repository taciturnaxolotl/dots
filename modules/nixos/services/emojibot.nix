# Emojibot - Slack emoji management service
#
# Stateless service, no database backup needed
# Supports multiple instances for different Slack workspaces

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.atelier.services.emojibot;
  
  enabledInstances = filterAttrs (n: v: v.enable) cfg.instances;
  
  mapInstances = function: mkMerge (mapAttrsToList function enabledInstances);

in {
  options.atelier.services.emojibot = {
    instances = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          enable = mkEnableOption "Enable this emojibot instance";

          domain = mkOption {
            type = types.str;
            description = "Domain to serve emojibot on";
          };

          port = mkOption {
            type = types.port;
            description = "Port to run emojibot on";
          };

          secretsFile = mkOption {
            type = types.path;
            description = "Path to agenix secrets file containing Slack credentials";
          };

          repository = mkOption {
            type = types.str;
            default = "https://github.com/taciturnaxolotl/emojibot";
            description = "Git repository URL for emojibot";
          };

          workspace = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Slack workspace name (non-sensitive, for identification)";
          };

          channel = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Slack channel ID (non-sensitive, can be public)";
          };
        };
      });
      default = {};
      description = "Emojibot instances to run";
    };
  };

  config.users.users = mapInstances (name: instanceCfg: {
    "emojibot-${name}" = {
      isSystemUser = true;
      group = "emojibot-${name}";
      extraGroups = [ "services" ];
      home = "/var/lib/emojibot-${name}";
      createHome = true;
      shell = pkgs.bash;
    };
  });

  config.users.groups = mapInstances (name: instanceCfg: {
    "emojibot-${name}" = {};
  });

  config.systemd.services = mapInstances (name: instanceCfg: {
    "emojibot-${name}" = {
      description = "Emojibot for ${if instanceCfg.workspace != null then instanceCfg.workspace else name}";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      path = [ pkgs.git pkgs.openssh ];

      preStart = ''
        set -e
        export GIT_TERMINAL_PROMPT=0
        
        # Clone repository if not present
        if [ ! -d /var/lib/emojibot-${name}/app/.git ]; then
          echo "Cloning ${instanceCfg.repository}..."
          ${pkgs.git}/bin/git clone -b main ${instanceCfg.repository} /var/lib/emojibot-${name}/app || {
            echo "Failed to clone repository. If this is a private repo, ensure SSH keys are configured."
            echo "For public repos, check network connectivity."
            exit 1
          }
        fi
        
        cd /var/lib/emojibot-${name}/app
        ${pkgs.git}/bin/git fetch origin
        ${pkgs.git}/bin/git reset --hard origin/main
        
        if [ -f package.json ]; then
          echo "Installing dependencies..."
          ${pkgs.unstable.bun}/bin/bun install || {
            echo "Failed to install dependencies, trying again..."
            ${pkgs.unstable.bun}/bin/bun install
          }
        fi
      '';

      serviceConfig = {
        Type = "exec";
        User = "emojibot-${name}";
        Group = "emojibot-${name}";
        WorkingDirectory = "/var/lib/emojibot-${name}";
        EnvironmentFile = instanceCfg.secretsFile;
        Environment = [
          "NODE_ENV=production"
          "PORT=${toString instanceCfg.port}"
        ] ++ optionals (instanceCfg.workspace != null) [
          "SLACK_WORKSPACE=${instanceCfg.workspace}"
        ] ++ optionals (instanceCfg.channel != null) [
          "SLACK_CHANNEL=${instanceCfg.channel}"
        ];
        ExecStart = "${pkgs.bash}/bin/bash -c 'cd /var/lib/emojibot-${name}/app && ${pkgs.unstable.bun}/bin/bun run src/index.ts'";
        Restart = "on-failure";
        RestartSec = "10s";
        TimeoutStartSec = "60s";
        
        # Security hardening
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ "/var/lib/emojibot-${name}" ];
        PrivateTmp = true;
      };

      serviceConfig.ExecStartPre = [
        "!${pkgs.writeShellScript "emojibot-${name}-setup" ''
          mkdir -p /var/lib/emojibot-${name}/app/data
          mkdir -p /var/lib/emojibot-${name}/data
          chown -R emojibot-${name}:services /var/lib/emojibot-${name}
          chmod -R g+rwX /var/lib/emojibot-${name}
        ''}"
      ];
    };
  });

  config.systemd.tmpfiles.rules = flatten (mapAttrsToList (name: instanceCfg: 
    optionals instanceCfg.enable [
      "d /var/lib/emojibot-${name} 0755 emojibot-${name} services -"
      "d /var/lib/emojibot-${name}/app 0755 emojibot-${name} services -"
      "d /var/lib/emojibot-${name}/data 0755 emojibot-${name} services -"
    ]
  ) enabledInstances);

  config.services.caddy.virtualHosts = mapInstances (name: instanceCfg: {
    ${instanceCfg.domain} = {
      extraConfig = ''
        tls {
          dns cloudflare {env.CLOUDFLARE_API_TOKEN}
        }
        header {
          Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        }
        reverse_proxy localhost:${toString instanceCfg.port} {
          header_up X-Forwarded-Proto {scheme}
          header_up X-Forwarded-For {remote}
        }
      '';
    };
  });

  config.security.sudo.extraRules = flatten (mapAttrsToList (name: instanceCfg:
    optionals instanceCfg.enable [
      {
        users = [ "emojibot-${name}" ];
        commands = [
          {
            command = "/run/current-system/sw/bin/systemctl restart emojibot-${name}.service";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ]
  ) enabledInstances);
}
