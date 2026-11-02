# PhotoPrism - self-hosted photo library
#
# Wraps the NixOS photoprism module with a static user, originals on a
# configurable path, optional Caddy vhost, and atelier manifest/backup
# integration.
#
# Upstream runs it as a DynamicUser with PrivateUsers, which is fine when
# everything lives under /var/lib. Here the originals sit on a shared pool that
# samba writes into as group `media`, so it needs a stable uid (dynamic ones
# get shoved around and orphan files) and real supplementary groups, which
# PrivateUsers maps to nobody.

{
  config,
  lib,
  ...
}:

let
  cfg = config.atelier.services.photoprism;
in
{
  options.atelier.services.photoprism = {
    enable = lib.mkEnableOption "PhotoPrism photo library";

    domain = lib.mkOption {
      type = lib.types.str;
      description = "Public domain PhotoPrism is reached at";
    };

    _description = lib.mkOption {
      type = lib.types.str;
      default = "PhotoPrism photo library";
      internal = true;
      readOnly = true;
    };

    _runtime = lib.mkOption {
      type = lib.types.str;
      default = "go";
      internal = true;
      readOnly = true;
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 2342;
      description = "Port PhotoPrism listens on";
    };

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Address PhotoPrism binds to";
    };

    serveVhost = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Serve the domain from this machine's Caddy. Off when another box fronts it.";
    };

    originalsPath = lib.mkOption {
      type = lib.types.str;
      description = "Where original photos and videos live";
    };

    importPath = lib.mkOption {
      type = lib.types.str;
      description = "Drop folder PhotoPrism moves files out of into the originals";
    };

    adminUser = lib.mkOption {
      type = lib.types.str;
      default = "admin";
      description = "Initial admin username";
    };

    passwordFile = lib.mkOption {
      type = lib.types.path;
      description = "File holding the initial admin password (8+ characters)";
    };

    uid = lib.mkOption {
      type = lib.types.int;
      description = "Pinned uid/gid for the photoprism account";
    };

    extraGroups = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Supplementary groups, e.g. one shared with samba";
    };

    nvidiaGpu = lib.mkEnableOption "NVENC video transcoding on an NVIDIA GPU";

    trustedProxies = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "127.0.0.1/32" ];
      description = "Proxies whose X-Forwarded-For PhotoPrism believes";
    };

    healthUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Health check URL for monitoring";
    };

    data = {
      sqlite = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
      postgres = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
      files = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
      };
      exclude = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
      };
      stopForBackup = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };
      stopUnits = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
      };
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.photoprism.gid = cfg.uid;
    users.users.photoprism = {
      uid = cfg.uid;
      group = "photoprism";
      extraGroups = cfg.extraGroups;
      isSystemUser = true;
      home = "/var/lib/photoprism";
    };

    services.photoprism = {
      enable = true;
      address = cfg.listenAddress;
      port = cfg.port;
      originalsPath = cfg.originalsPath;
      importPath = cfg.importPath;
      passwordFile = cfg.passwordFile;
      settings = {
        PHOTOPRISM_SITE_URL = "https://${cfg.domain}/";
        PHOTOPRISM_SITE_TITLE = "PhotoPrism";
        PHOTOPRISM_ADMIN_USER = cfg.adminUser;
        PHOTOPRISM_AUTH_MODE = "password";
        PHOTOPRISM_DATABASE_DRIVER = "sqlite";
        PHOTOPRISM_DISABLE_TLS = "true";
        PHOTOPRISM_TRUSTED_PROXY = lib.concatStringsSep "," cfg.trustedProxies;
        PHOTOPRISM_ORIGINALS_LIMIT = "10000";
      }
      // lib.optionalAttrs cfg.nvidiaGpu {
        PHOTOPRISM_FFMPEG_ENCODER = "nvidia";
      };
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.originalsPath} 2775 photoprism ${lib.head (cfg.extraGroups ++ [ "photoprism" ])} -"
      "d ${cfg.importPath} 2775 photoprism ${lib.head (cfg.extraGroups ++ [ "photoprism" ])} -"
    ];

    systemd.services.photoprism = {
      unitConfig.RequiresMountsFor = [
        cfg.originalsPath
        cfg.importPath
      ];
      serviceConfig = {
        DynamicUser = lib.mkForce false;
        PrivateUsers = lib.mkForce false;
        # Upstream's 0066 leaves imported files unreadable to the shared group,
        # so the samba side could drop photos in but never see them again.
        UMask = lib.mkForce "0002";
      }
      // lib.optionalAttrs cfg.nvidiaGpu {
        # Upstream hides every device node. Open just the GPU: the nodes are
        # 0666, and the nixpkgs ffmpeg already finds the driver libraries.
        PrivateDevices = lib.mkForce false;
        DevicePolicy = "closed";
        DeviceAllow = [
          "/dev/nvidiactl rw"
          "/dev/nvidia0 rw"
          "/dev/nvidia-uvm rw"
          "/dev/nvidia-uvm-tools rw"
          "/dev/nvidia-modeset rw"
        ];
      };
    };

    atelier.services.photoprism.data = {
      # The sqlite dir is /var/lib/photoprism itself, so sidecars and config
      # come along with the index.
      sqlite = "/var/lib/photoprism/index.db";
      files = [ cfg.originalsPath ];
      # Thumbnails and transcodes regenerate from the originals.
      exclude = [
        "/var/lib/photoprism/cache"
        "*.log"
      ];
    };

    services.caddy.virtualHosts.${cfg.domain} = lib.mkIf cfg.serveVhost {
      extraConfig = ''
        tls {
          dns cloudflare {env.CLOUDFLARE_API_TOKEN}
        }
        header {
          Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        }

        reverse_proxy ${cfg.listenAddress}:${toString cfg.port}
      '';
    };
  };
}
