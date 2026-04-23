{
  lib,
  config,
  inputs,
  ...
}:
let
  cfg = config.atelier.services.tangled;
in
{
  options.atelier.services.tangled = {
    enable = lib.mkEnableOption "Tangled knot and spindle";

    owner = lib.mkOption {
      type = lib.types.str;
      description = "did of owner";
    };

    knot = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Run a knot server";
      };

      port = lib.mkOption {
        type = lib.types.int;
        default = 5555;
      };

      internalListenAddr = lib.mkOption {
        type = lib.types.int;
        default = 5444;
      };

      motd = lib.mkOption {
        type = lib.types.str;
        default = "Welcome to the knot!";
        description = "Welcome message for the knot when doing push or pulling";
      };

      hostname = lib.mkOption {
        type = lib.types.str;
      };

      syncSecretsFile = lib.mkOption {
        type = lib.types.path;
        description = "Path to secrets file containing GITHUB_TOKEN";
      };
    };

    spindle = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Run a spindle workflow server";
      };

      port = lib.mkOption {
        type = lib.types.int;
        default = 6555;
      };

      hostname = lib.mkOption {
        type = lib.types.str;
      };
    };
  };

  imports = [
    inputs.tangled.nixosModules.knot
    inputs.tangled.nixosModules.spindle
  ];

  config = lib.mkIf cfg.enable {

    services.tangled.knot = {
      enable = cfg.knot.enable;
      server = {
        owner = cfg.owner;
        hostname = cfg.knot.hostname;
        listenAddr = "127.0.0.1:${toString cfg.knot.port}";
        internalListenAddr = "127.0.0.1:${toString cfg.knot.internalListenAddr}";
      };
      motd = cfg.knot.motd;
    };

    services.tangled.spindle = {
      enable = cfg.spindle.enable;
      server = {
        owner = cfg.owner;
        hostname = cfg.spindle.hostname;
        listenAddr = "127.0.0.1:${toString cfg.spindle.port}";
      };
    };

    # Backup configuration for tangled services
    atelier.backup.services.knot = lib.mkIf cfg.knot.enable {
      paths = [ "/home/git" ]; # Git repositories managed by knot
      exclude = [ "*.log" ];
      # Uses SQLite, stop before backup
      preBackup = "systemctl stop knot";
      postBackup = "systemctl start knot";
    };

    atelier.backup.services.spindle = lib.mkIf cfg.spindle.enable {
      paths = [ "/var/lib/spindle" ];
      exclude = [
        "*.log"
        "cache/*"
      ];
      # Uses SQLite, stop before backup
      preBackup = "systemctl stop spindle";
      postBackup = "systemctl start spindle";
    };

    atelier.services.knot-sync = {
      enable = cfg.knot.enable;
      secretsFile = cfg.knot.syncSecretsFile;
    };

    services.caddy = {
      virtualHosts."${cfg.knot.hostname}" = lib.mkIf cfg.knot.enable {
        extraConfig = ''
          tls {
            dns cloudflare {env.CLOUDFLARE_API_TOKEN}
          }
          header {
            Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
          }
          reverse_proxy localhost:${toString cfg.knot.port} {
            header_up X-Forwarded-Proto {scheme}
            header_up X-Forwarded-For {remote}
          }
        '';
      };
      virtualHosts."${cfg.spindle.hostname}" = lib.mkIf cfg.spindle.enable {
        extraConfig = ''
          tls {
            dns cloudflare {env.CLOUDFLARE_API_TOKEN}
          }
          header {
            Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
          }
          reverse_proxy localhost:${toString cfg.spindle.port} {
            header_up X-Forwarded-Proto {scheme}
            header_up X-Forwarded-For {remote}
          }
        '';
      };
    };
  };
}
