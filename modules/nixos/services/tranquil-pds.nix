# Tranquil PDS - AT Protocol Personal Data Server
#
# A feature-rich PDS with passkeys, 2FA, did:web support, and more.
# Requires PostgreSQL, Redis, and S3-compatible storage.

{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.atelier.services.tranquil-pds;
in
{
  options.atelier.services.tranquil-pds = {
    enable = lib.mkEnableOption "Tranquil PDS";

    package = lib.mkOption {
      type = lib.types.package;
      default = inputs.tranquil-pds.packages.${pkgs.stdenv.hostPlatform.system}.default;
      description = "The tranquil-pds package to use";
    };

    domain = lib.mkOption {
      type = lib.types.str;
      description = "Primary domain for the PDS (e.g., serif.blue)";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3100;
      description = "Port for the PDS to listen on";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/tranquil-pds";
      description = "Directory to store PDS data";
    };

    secretsFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to agenix secrets file containing JWT_SECRET, DPOP_SECRET, MASTER_KEY, and S3 credentials";
    };

    database = {
      name = lib.mkOption {
        type = lib.types.str;
        default = "tranquil-pds";
        description = "PostgreSQL database name";
      };

      user = lib.mkOption {
        type = lib.types.str;
        default = "tranquil-pds";
        description = "PostgreSQL user";
      };
    };

    s3 = {
      endpoint = lib.mkOption {
        type = lib.types.str;
        default = "http://localhost:9000";
        description = "S3-compatible endpoint URL";
      };

      bucket = lib.mkOption {
        type = lib.types.str;
        default = "pds-blobs";
        description = "S3 bucket name for blob storage";
      };

      region = lib.mkOption {
        type = lib.types.str;
        default = "us-east-1";
        description = "S3 region";
      };
    };

    minio = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable local MinIO for S3-compatible storage. Disable if using Backblaze B2 or AWS S3.";
      };
    };

    redis = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Redis for caching and rate limiting";
      };
    };

    crawlers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "https://bsky.network" ];
      description = "Relay URLs to notify via requestCrawl";
    };

    acceptingRepoImports = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to accept repository imports (account migration)";
    };

    availableUserDomains = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Available user domains for handles (e.g., [\"serif.blue\"])";
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.tranquil-pds = {
      isSystemUser = true;
      group = "tranquil-pds";
      home = cfg.dataDir;
      createHome = true;
    };
    users.groups.tranquil-pds = { };

    services.postgresql = {
      enable = true;
      ensureDatabases = [ cfg.database.name ];
      ensureUsers = [
        {
          name = cfg.database.user;
          ensureDBOwnership = true;
        }
      ];
    };

    services.redis.servers.tranquil-pds = lib.mkIf cfg.redis.enable {
      enable = true;
      port = 6379;
    };

    services.minio = lib.mkIf cfg.minio.enable {
      enable = true;
      dataDir = [ "${cfg.dataDir}/minio" ];
      rootCredentialsFile = cfg.secretsFile;
    };

    systemd.services.tranquil-pds = {
      description = "Tranquil PDS - AT Protocol Personal Data Server";
      wantedBy = [ "multi-user.target" ];
      after =
        [
          "network.target"
          "postgresql.service"
        ]
        ++ lib.optional cfg.minio.enable "minio.service"
        ++ lib.optional cfg.redis.enable "redis-tranquil-pds.service";
      requires =
        [ "postgresql.service" ]
        ++ lib.optional cfg.minio.enable "minio.service"
        ++ lib.optional cfg.redis.enable "redis-tranquil-pds.service";

      environment =
        {
          SERVER_HOST = "127.0.0.1";
          SERVER_PORT = toString cfg.port;
          PDS_HOSTNAME = cfg.domain;
          DATABASE_URL = "postgres:///${cfg.database.name}?host=/run/postgresql";
          S3_ENDPOINT = cfg.s3.endpoint;
          S3_BUCKET = cfg.s3.bucket;
          AWS_REGION = cfg.s3.region;
          CRAWLERS = lib.concatStringsSep "," cfg.crawlers;
          ACCEPTING_REPO_IMPORTS = if cfg.acceptingRepoImports then "true" else "false";
          AVAILABLE_USER_DOMAINS = lib.concatStringsSep "," cfg.availableUserDomains;
        }
        // lib.optionalAttrs cfg.redis.enable {
          REDIS_URL = "redis://localhost:6379";
        };

      serviceConfig = {
        Type = "simple";
        User = "tranquil-pds";
        Group = "tranquil-pds";
        WorkingDirectory = cfg.dataDir;
        EnvironmentFile = lib.mkIf (cfg.secretsFile != null) cfg.secretsFile;
        ExecStart = "${cfg.package}/bin/tranquil-pds";
        Restart = "always";
        RestartSec = "10s";

        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ cfg.dataDir ];
        PrivateTmp = true;
      };
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 tranquil-pds tranquil-pds -"
    ] ++ lib.optional cfg.minio.enable "d ${cfg.dataDir}/minio 0755 minio minio -";

    services.caddy.virtualHosts."${cfg.domain}" = {
      extraConfig = ''
                tls {
                  dns cloudflare {env.CLOUDFLARE_API_TOKEN}
                }
                header {
                  Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
                }
                
                # Serve ASCII banner for root path
                handle / {
                  header Content-Type "text/plain; charset=utf-8"
                  respond `
           _____ ______ _____  _____ ______   ____  _      _    _ ______ 
          / ____|  ____|  __ \|_   _|  ____| |  _ \| |    | |  | |  ____|
         | (___ | |__  | |__) | | | | |__    | |_) | |    | |  | | |__   
          \___ \|  __| |  _  /  | | |  __|   |  _ <| |    | |  | |  __|  
          ____) | |____| | \ \ _| |_| |      | |_) | |____| |__| | |____ 
         |_____/|______|_|  \_\_____|_|      |____/|______|\____/|______|
                                                                          
         AT Protocol Personal Data Server
         
         This is a PDS instance running on ${cfg.domain}
         
         Powered by Tranquil PDS
         https://tangled.org/lewis.moe/bspds-sandbox/
        ` 200
                }
                
                reverse_proxy localhost:${toString cfg.port} {
                  header_up X-Forwarded-Proto {scheme}
                  header_up X-Forwarded-For {remote}
                }
      '';
    };

    services.caddy.virtualHosts."*.${cfg.domain}" = {
      extraConfig = ''
        tls {
          dns cloudflare {env.CLOUDFLARE_API_TOKEN}
        }
        header {
          Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        }
        reverse_proxy localhost:${toString cfg.port} {
          header_up X-Forwarded-Proto {scheme}
          header_up X-Forwarded-For {remote}
        }
      '';
    };

    networking.firewall.allowedTCPPorts = [
      443
      80
    ];

    atelier.backup.services.tranquil-pds = {
      paths = [ cfg.dataDir ];
      exclude = [ "*.log" ] ++ lib.optional cfg.minio.enable "minio/*";
      preBackup = ''
        systemctl stop tranquil-pds
        ${pkgs.sudo}/bin/sudo -u postgres ${pkgs.postgresql}/bin/pg_dump ${cfg.database.name} > /tmp/tranquil-pds-pg-dump.sql
      '';
      postBackup = "systemctl start tranquil-pds";
    };
  };
}
