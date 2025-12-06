{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.atelier.services.battleship-arena;
in
{
  options.atelier.services.battleship-arena = {
    enable = mkEnableOption "battleship-arena service";

    domain = mkOption {
      type = types.str;
      default = "battleship.dunkirk.sh";
      description = "Domain name for the web interface";
    };

    sshPort = mkOption {
      type = types.port;
      default = 2222;
      description = "SSH port for battleship arena";
    };

    webPort = mkOption {
      type = types.port;
      default = 8081;
      description = "Web interface port";
    };

    uploadDir = mkOption {
      type = types.str;
      default = "/var/lib/battleship-arena/submissions";
      description = "Directory for uploaded submissions";
    };

    resultsDb = mkOption {
      type = types.str;
      default = "/var/lib/battleship-arena/results.db";
      description = "Path to results database";
    };

    adminPasscode = mkOption {
      type = types.str;
      default = "battleship-admin-override";
      description = "Admin passcode for batch uploads";
    };

    secretsFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to agenix secrets file containing BATTLESHIP_ADMIN_PASSCODE";
    };

    package = mkOption {
      type = types.package;
      description = "The battleship-arena package to use";
    };
  };

  config = mkIf cfg.enable {
    users.users.battleship-arena = {
      isSystemUser = true;
      group = "battleship-arena";
      home = "/var/lib/battleship-arena";
      createHome = true;
    };

    users.groups.battleship-arena = {};

    systemd.services.battleship-arena = {
      description = "Battleship Arena SSH/Web Service";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      environment = {
        BATTLESHIP_HOST = "0.0.0.0";
        BATTLESHIP_SSH_PORT = toString cfg.sshPort;
        BATTLESHIP_WEB_PORT = toString cfg.webPort;
        BATTLESHIP_UPLOAD_DIR = cfg.uploadDir;
        BATTLESHIP_RESULTS_DB = cfg.resultsDb;
        BATTLESHIP_ADMIN_PASSCODE = cfg.adminPasscode;
        BATTLESHIP_EXTERNAL_URL = "https://${cfg.domain}";
        BATTLESHIP_ENGINE_PATH = "/var/lib/battleship-arena/battleship-engine";
        CPLUS_INCLUDE_PATH = "/var/lib/battleship-arena/battleship-engine/include";
      };

      path = [ pkgs.gcc pkgs.coreutils ];

      serviceConfig = {
        Type = "simple";
        User = "battleship-arena";
        Group = "battleship-arena";
        WorkingDirectory = "/var/lib/battleship-arena";
        ExecStart = "${cfg.package}/bin/battleship-arena";
        Restart = "always";
        RestartSec = "10s";

        # Load secrets if provided
        EnvironmentFile = mkIf (cfg.secretsFile != null) cfg.secretsFile;

        # Security hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ "/var/lib/battleship-arena" ];
      };

      preStart = ''
        mkdir -p ${cfg.uploadDir}
        mkdir -p $(dirname ${cfg.resultsDb})
        chown -R battleship-arena:battleship-arena ${cfg.uploadDir}
        chmod -R u+rwX ${cfg.uploadDir}
        
        # Generate SSH host key if it doesn't exist
        if [ ! -f /var/lib/battleship-arena/.ssh/battleship_arena ]; then
          mkdir -p /var/lib/battleship-arena/.ssh
          ${pkgs.openssh}/bin/ssh-keygen -t ed25519 -f /var/lib/battleship-arena/.ssh/battleship_arena -N ""
          chown -R battleship-arena:battleship-arena /var/lib/battleship-arena/.ssh
        fi
        
        # Copy battleship-engine to writable directory
        chmod -R u+w /var/lib/battleship-arena/battleship-engine 2>/dev/null || true
        rm -rf /var/lib/battleship-arena/battleship-engine
        cp -r ${cfg.package}/share/battleship-arena/battleship-engine /var/lib/battleship-arena/
        chown -R battleship-arena:battleship-arena /var/lib/battleship-arena/battleship-engine
        chmod -R u+rwX /var/lib/battleship-arena/battleship-engine
      '';
    };

    # Service to recalculate Glicko-2 ratings (manual trigger only)
    # Ratings automatically recalculate after each round-robin
    # Use: sudo systemctl start battleship-arena-recalculate
    systemd.services.battleship-arena-recalculate = {
      description = "Recalculate Battleship Arena Glicko-2 Ratings";
      
      environment = {
        BATTLESHIP_RESULTS_DB = cfg.resultsDb;
      };

      serviceConfig = {
        Type = "oneshot";
        User = "battleship-arena";
        Group = "battleship-arena";
        WorkingDirectory = "/var/lib/battleship-arena";
        ExecStart = "${cfg.package}/bin/battleship-arena recalculate-ratings";
      };
    };

    # Allow battleship-arena user to create transient systemd units for sandboxing
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (action.id == "org.freedesktop.systemd1.manage-units" &&
            subject.user == "battleship-arena") {
          return polkit.Result.YES;
        }
      });
    '';

    networking.firewall.allowedTCPPorts = [ cfg.sshPort ];
  };
}
