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

      maxJobCount = lib.mkOption {
        type = lib.types.int;
        default = 2;
        description = ''
          Max pipelines running concurrently. Each microVM job is 4 GiB / 2
          vCPU (the nixos image spec), so size this to the host: leave RAM and
          CPU headroom for anything else the machine runs. Aggregate microVM
          and nixery caps below are derived from this so a burst can't
          over-allocate.
        '';
      };
    };
  };

  imports = [
    inputs.tangled.nixosModules.knot
    inputs.tangled.nixosModules.spindle
  ];

  # knot and spindle are gated independently so a machine can run just one
  # (e.g. spindle on a KVM host, knot elsewhere).
  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.mkIf cfg.spindle.enable {
        services.tangled.spindle = {
          enable = true;
          server = {
            owner = cfg.owner;
            hostname = cfg.spindle.hostname;
            listenAddr = "${cfg.spindle.bindAddr}:${toString cfg.spindle.port}";
            maxJobCount = cfg.spindle.maxJobCount;
          };

          pipelines = {
            # No S3 log archival: only the bucket name can be set here (creds,
            # region, endpoint would come from AWS_* env we don't provide), so
            # uploads just error out. Logs are written to /var/log/spindle and
            # the UI streams them from there, so an empty bucket disables the
            # broken S3 path cleanly (NewS3 short-circuits on "").
            logBucket = "";

            # Aggregate ceilings so a workflow requesting a larger-than-default VM
            # (or a burst) can't exceed the job-count budget. Mirror the nixos
            # image spec: 4 GiB / 2 vCPU per microVM.
            microvm.limits.total = {
              memoryMiB = cfg.spindle.maxJobCount * 4096;
              vcpus = cfg.spindle.maxJobCount * 2;
            };

            # Keep nixery workflow concurrency in line with the job budget too
            # (6 GiB per container; the default of 8 could otherwise over-commit).
            nixery.maxConcurrentWorkflows = cfg.spindle.maxJobCount;
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

        # Contain knot's memory leak. GOMEMLIMIT gives Go a budget it will
        # actually collect against; MemoryMax is only the backstop, sized above
        # it so the kernel steps in solely when Go has already lost.
        #
        # There is deliberately no MemoryHigh. MemoryHigh throttles rather than
        # kills, so a leaking knot gets pinned in reclaim in D state, where it
        # cannot be signalled at all: no OOM kill, no SIGTERM, no restart, just
        # a wedged unit and system-wide memory stall until someone lifts the
        # limit by hand. A hard MemoryMax with Restart=always self-heals in
        # seconds instead. Swap is left enabled for the same reason, so reclaim
        # always has somewhere to go.
        systemd.services.knot = {
          environment.GOMEMLIMIT = "3GiB";
          serviceConfig.MemoryMax = "4G";
        };

        # Proactively restart knot every 4 hours so the leak is usually cleared
        # on a schedule rather than by hitting MemoryMax mid-request.
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
    ]
  );
}
