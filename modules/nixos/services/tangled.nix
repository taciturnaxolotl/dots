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
        default = "";
      };

      syncSecretsFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
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

      bindAddr = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = ''
          Address the spindle HTTP server binds to. Default is loopback.
          Set to "0.0.0.0" when a separate public host reverse-proxies the
          spindle over Tailscale (restrict the port to tailscale0 in the
          firewall so it isn't exposed on other interfaces).
        '';
      };

      hostname = lib.mkOption {
        type = lib.types.str;
        default = "";
      };
    };
  };

  imports = [
    inputs.tangled.nixosModules.knot
    inputs.tangled.nixosModules.spindle
  ];

  # knot and spindle are gated independently so a machine can run just one
  # (e.g. spindle on a KVM host, knot elsewhere).
  config = lib.mkIf cfg.enable (lib.mkMerge [
    (lib.mkIf cfg.spindle.enable {
      services.tangled.spindle = {
        enable = true;
        server = {
          owner = cfg.owner;
          hostname = cfg.spindle.hostname;
          listenAddr = "${cfg.spindle.bindAddr}:${toString cfg.spindle.port}";
        };
      };

      atelier.backup.services.spindle = {
        paths = [ "/var/lib/spindle" ];
        exclude = [
          "*.log"
          "cache/*"
        ];
        # Uses SQLite, stop before backup
        preBackup = "systemctl stop spindle";
        postBackup = "systemctl start spindle";
      };

      # The public endpoint (hostname over HTTPS) is served by whichever host
      # fronts the internet, reverse-proxying to this spindle over Tailscale.
      # That host is often not the spindle host (e.g. a NAT'd KVM box), so the
      # caddy vhost lives there, not here.
    })

    (lib.mkIf cfg.knot.enable {
      services.tangled.knot = {
        enable = true;
        server = {
          owner = cfg.owner;
          hostname = cfg.knot.hostname;
          listenAddr = "127.0.0.1:${toString cfg.knot.port}";
          internalListenAddr = "127.0.0.1:${toString cfg.knot.internalListenAddr}";
        };
        motd = cfg.knot.motd;
      };

      # Backup configuration for the knot's git repositories
      atelier.backup.services.knot = {
        paths = [ "/home/git" ]; # Git repositories managed by knot
        exclude = [ "*.log" ];
        # Uses SQLite, stop before backup
        preBackup = "systemctl stop knot";
        postBackup = "systemctl start knot";
      };

      # Prevent knot's memory leak from triggering system-wide OOM
      # MemoryMax: hard kill at 4G (process is unresponsive well before 8G)
      # MemoryHigh: throttle at 3G to slow growth
      # MemorySwapMax: prevent swap thrashing entirely
      systemd.services.knot.serviceConfig = {
        MemoryMax = "8G";
        MemoryHigh = "6G";
        MemorySwapMax = "0";
      };

      # Proactively restart knot every 4 hours to prevent memory bloat
      # from accumulating. The RepoCompare endpoint leaks ~1.5GB/hour under
      # normal traffic, so 4h keeps it well under the 4G hard limit.
      systemd.timers.knot-restart = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "*-*-* 00/4:00:00";
          Persistent = true;
        };
      };
      systemd.services.knot-restart = {
        serviceConfig.Type = "oneshot";
        script = "${config.systemd.package}/bin/systemctl restart knot";
      };

      # Fix race condition: chown -R fails if SQLite WAL temp files (-wal, -shm)
      # vanish during the pre-start script, causing the service to fail to start
      systemd.services.knot.preStart = lib.mkForce ''
        mkdir -p "/home/git"
        chown -R git:git "/home/git" || true

        mkdir -p "/home/git/.config/git"
        cat > "/home/git/.config/git/config" << EOF
        [user]
            name = Tangled
            email = noreply@tangled.org
        [receive]
            advertisePushOptions = true
        [uploadpack]
            allowFilter = true
            allowReachableSHA1InWant = true
        EOF
        printf "🧶 welcome to kieran's knot!\n" > /home/git/motd
        chown -R git:git "/home/git" || true
      '';

      atelier.services.knot-sync = {
        enable = true;
        ownerDid = cfg.owner;
        secretsFile = cfg.knot.syncSecretsFile;
      };

      services.caddy.virtualHosts."${cfg.knot.hostname}".extraConfig = ''
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
    })
  ]);
}
