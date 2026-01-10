# Herald - RSS-to-Email via SSH
#
# Feeds uploaded via SSH/SCP, emails sent on schedule

{ config, lib, pkgs, ... }:

let
  cfg = config.atelier.services.herald;
  
  # Generate config.yaml from options
  configFile = pkgs.writeText "herald-config.yaml" ''
    host: ${cfg.host}
    ssh_port: ${toString cfg.sshPort}
    http_port: ${toString cfg.httpPort}
    origin: https://${cfg.domain}
    external_ssh_port: ${toString cfg.externalSshPort}
    
    host_key_path: ${cfg.dataDir}/host_key
    db_path: ${cfg.dataDir}/herald.db
    
    smtp:
      host: ${cfg.smtp.host}
      port: ${toString cfg.smtp.port}
      user: ${cfg.smtp.user}
      pass: ''${SMTP_PASS}
      from: ${cfg.smtp.from}
      ${lib.optionalString (cfg.smtp.dkim.selector != null) ''dkim_selector: ${cfg.smtp.dkim.selector}''}
      ${lib.optionalString (cfg.smtp.dkim.domain != null) ''dkim_domain: ${cfg.smtp.dkim.domain}''}
      ${lib.optionalString (cfg.smtp.dkim.privateKeyFile != null) ''dkim_private_key_file: ${cfg.smtp.dkim.privateKeyFile}''}
    
    allow_all_keys: ${if cfg.allowAllKeys then "true" else "false"}
  '';
in
{
  options.atelier.services.herald = {
    enable = lib.mkEnableOption "Herald RSS-to-Email service";

    domain = lib.mkOption {
      type = lib.types.str;
      description = "Domain to serve Herald on";
      example = "herald.dunkirk.sh";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
      description = "Host address to bind to";
    };

    sshPort = lib.mkOption {
      type = lib.types.port;
      default = 2223;
      description = "Internal SSH port for Herald";
    };

    externalSshPort = lib.mkOption {
      type = lib.types.port;
      default = 2223;
      description = "External SSH port (for display in UI)";
    };

    httpPort = lib.mkOption {
      type = lib.types.port;
      default = 8085;
      description = "Internal HTTP port for Herald web interface";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/herald";
      description = "Directory to store Herald data";
    };

    allowAllKeys = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Allow all SSH keys (false to use allowed_keys)";
    };

    smtp = {
      host = lib.mkOption {
        type = lib.types.str;
        description = "SMTP server host";
        example = "smtp.gmail.com";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 587;
        description = "SMTP server port";
      };

      user = lib.mkOption {
        type = lib.types.str;
        description = "SMTP username";
      };

      from = lib.mkOption {
        type = lib.types.str;
        description = "From address for emails";
        example = "herald@dunkirk.sh";
      };

      dkim = {
        selector = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "DKIM selector";
          example = "mailchannels";
        };

        domain = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "DKIM domain";
          example = "dunkirk.sh";
        };

        privateKeyFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = "Path to DKIM private key file";
          example = "/var/lib/herald/dkim_private.pem";
        };
      };
    };

    secretsFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to agenix secrets file (must contain SMTP_PASS)";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.herald;
      description = "Herald package to use";
    };
  };

  config = lib.mkIf cfg.enable {
    # Create user and group
    users.groups.services = {};
    
    users.users.herald = {
      isSystemUser = true;
      group = "herald";
      extraGroups = [ "services" ];
      home = cfg.dataDir;
      createHome = true;
      shell = pkgs.bash;
    };

    users.groups.herald = {};

    # Systemd service
    systemd.services.herald = {
      description = "Herald RSS-to-Email service";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        Type = "simple";
        User = "herald";
        Group = "herald";
        WorkingDirectory = cfg.dataDir;
        EnvironmentFile = cfg.secretsFile;
        ExecStart = "${cfg.package}/bin/herald serve -c ${configFile}";
        Restart = "always";
        RestartSec = "10s";
        
        # Security hardening
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ cfg.dataDir ];
        PrivateTmp = true;
      };

      preStart = ''
        mkdir -p ${cfg.dataDir}
        chown -R herald:services ${cfg.dataDir}
        chmod -R g+rwX ${cfg.dataDir}
      '';
    };

    # Ensure working directory exists
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 herald services -"
    ];

    # Open firewall ports
    networking.firewall.allowedTCPPorts = [ cfg.sshPort ];

    # Caddy reverse proxy for HTTP interface
    services.caddy.virtualHosts.${cfg.domain} = {
      extraConfig = ''
        tls {
          dns cloudflare {env.CLOUDFLARE_API_TOKEN}
        }
        header {
          Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        }
        reverse_proxy localhost:${toString cfg.httpPort} {
          header_up X-Forwarded-Proto {scheme}
          header_up X-Forwarded-For {remote}
        }
      '';
    };

    # Backup configuration
    atelier.backup.services.herald = {
      paths = [ cfg.dataDir ];
      exclude = [ "*.log" ];
      # Uses SQLite, stop before backup
      preBackup = "systemctl stop herald";
      postBackup = "systemctl start herald";
    };
  };
}
