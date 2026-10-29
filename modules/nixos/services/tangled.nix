{
  lib,
  config,
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
        description = "Loopback HTTP port the knot listens on, behind caddy";
      };

      sshPort = lib.mkOption {
        type = lib.types.port;
        default = 22;
        description = ''
          Port the knot's own SSH server takes on every address. The appview
          builds clone URLs with no port in them, so anything but 22 means
          every user has to rewrite theirs. Taking 22 means sshd moves.
        '';
      };

      motd = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "Thanks for using {knot}!" ];
        description = "Lines shown on fetch; {knot} expands to the hostname";
      };

      hostname = lib.mkOption {
        type = lib.types.str;
        default = "";
      };

      masterKeyFile = lib.mkOption {
        type = lib.types.path;
        description = ''
          Environment file setting KNOT_MASTER_KEY, which unseals the knot's
          per-repository signing keys. Losing it makes them unreadable.
        '';
      };

      syncSecretsFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Environment file containing GITHUB_TOKEN; mirroring to GitHub is off while this is null";
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

          # No S3 artifact store: only the bucket name and region can be set
          # here (creds would come from AWS_* env we don't provide), so the
          # module's default "tangled-logs" bucket would just error out. An
          # empty bucket skips the S3 store entirely and leaves the disk store
          # (/var/log/spindle by default) as the only one, which the UI reads.
          artifactStores.s3.bucket = "";
          mill.artifactStore = "disk";

          pipelines = {
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
        # Knot 2: git is the database (no SQLite), it serves SSH in-process
        # with keys read live from each user's PDS, and it runs as `knot` out
        # of /var/lib/knot. Migrated from the Go knot with knot-migrate, which
        # left /home/git and knotserver.db untouched in case we go back.
        services.tangled.knot-rs = {
          enable = true;
          environmentFile = cfg.knot.masterKeyFile;
          settings = {
            server = {
              hostname = cfg.knot.hostname;
              admins = [ cfg.owner ];
              listen_addr = "127.0.0.1:${toString cfg.knot.port}";
              ssh_listen_addr = "[::]:${toString cfg.knot.sshPort}";
            };
            atproto.plc_directory = "https://plc.directory";
            # Every migrated repo is SHA-1, and a SHA-256 repo can't push to
            # or fetch from one, so new repos stay SHA-1 too.
            git.object_format = "sha1";
            # Caddy is the only thing that reaches the HTTP port, and it
            # replaces X-Forwarded-For with the real client for direct hits.
            xrpc = {
              trusted_proxy_header = "x-forwarded-for";
              trusted_proxies = [
                "127.0.0.1"
                "::1"
              ];
              # The appview polls collaborators for every repo in one burst
              # every few minutes, ~90 authenticated calls at once. The
              # default burst of 20 rejected ~70 of them each round.
              preauth_burst = 256;
            };
            messages.fetch.motd = cfg.knot.motd;
            # Caddy terminates TLS (and serves h3), so the knot never has a
            # certificate to do HTTP/3 with.
            tls.http3 = false;
          };
        };

        # The knot sizes itself to its cgroup, so this is a budget rather than
        # a leak backstop like the Go knot needed.
        systemd.services.knot-rs.serviceConfig.MemoryMax = "4G";

        # The whole knot is this directory plus the master key (in agenix):
        # repos/ holds every repo and the ACL, beside the sealed key store.
        # Stopped for the snapshot so restic never catches a half-written pack.
        atelier.backup.services.knot = {
          paths = [ "/var/lib/knot" ];
          preBackup = "systemctl stop knot-rs";
          postBackup = "systemctl start knot-rs";
        };

        atelier.services.knot-sync = lib.mkIf (cfg.knot.syncSecretsFile != null) {
          enable = true;
          knotUrl = "http://127.0.0.1:${toString cfg.knot.port}";
          knotHostname = cfg.knot.hostname;
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
          reverse_proxy localhost:${toString cfg.knot.port}
        '';
      })
    ]
  );
}
