{
  lib,
  config,
  ...
}:
let
  cfg = config.atelier.services.tangled;
  knotState = config.services.tangled.knot-rs.stateDir;
in
{
  options.atelier.services.tangled = {
    enable = lib.mkEnableOption "Tangled knot and spindle";

    owner = lib.mkOption {
      type = lib.types.str;
      description = "did of owner";
    };

    contactEmail = lib.mkOption {
      type = lib.types.str;
      default = "kieran@dunkirk.sh";
      description = "Operator contact the knot and spindle publish";
    };

    knot = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Run a knot server";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 5555;
        description = "Loopback HTTP port the knot listens on, behind caddy";
      };

      sshPort = lib.mkOption {
        type = lib.types.port;
        default = 22;
        description = "Port for the knot's own SSH server; clone URLs assume 22";
      };

      motd = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "Thanks for using {knot}!" ];
        description = "Lines shown on fetch; {knot} expands to the hostname";
      };

      hostname = lib.mkOption {
        type = lib.types.str;
        description = "Public hostname, which is also the knot's did:web identity";
      };

      masterKeyFile = lib.mkOption {
        type = lib.types.path;
        description = "Environment file setting KNOT_MASTER_KEY, which unseals the knot's signing keys";
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
        type = lib.types.port;
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
        description = "Public hostname, which is also the spindle's did:web identity";
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

      keyFile = lib.mkOption {
        type = lib.types.path;
        description = "PEM P-256 key behind the spindle's did:web document";
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
          keyPath = toString cfg.spindle.keyFile;
          contact.email = cfg.contactEmail;
          server = {
            owner = cfg.owner;
            hostname = cfg.spindle.hostname;
            listenAddr = "${cfg.spindle.bindAddr}:${toString cfg.spindle.port}";
            maxJobCount = cfg.spindle.maxJobCount;
          };

          # We have no S3 credentials, so keep artifacts on the disk store only.
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
            # Matches the migrated repos; SHA-256 ones can't exchange objects with them.
            git.object_format = "sha1";
            xrpc = {
              trusted_proxy_header = "x-forwarded-for";
              trusted_proxies = [
                "127.0.0.1"
                "::1"
              ];
              # The appview polls every repo in one burst; the default 20 rejected most of it.
              preauth_burst = 256;
            };
            contact.email = cfg.contactEmail;
            # Also holds social-record blobs, which foster handovers need.
            lfs.store_path = "${knotState}/lfs";
            messages.fetch.motd = cfg.knot.motd;
            # Caddy terminates TLS, so the knot has no certificate for h3.
            tls.http3 = false;
          };
        };

        # The knot sizes itself to its cgroup.
        systemd.services.knot-rs.serviceConfig.MemoryMax = "4G";

        # The state dir plus the agenix master key is the whole knot; stopped so no pack is half-written.
        atelier.backup.services.knot = {
          paths = [ knotState ];
          preBackup = "systemctl stop knot-rs";
          postBackup = "systemctl start knot-rs";
        };

        atelier.services.knot-sync = lib.mkIf (cfg.knot.syncSecretsFile != null) {
          enable = true;
          knotUrl = "http://127.0.0.1:${toString cfg.knot.port}";
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
