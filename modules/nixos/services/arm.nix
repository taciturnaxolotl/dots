# Automatic Ripping Machine (ARM) — optical disc ripper
#
# Runs the official ARM Docker image with optical drive passthrough.
# Rips DVDs/Blu-rays/CDs and outputs to /storage/media for Jellyfin.

{ config, lib, ... }:

let
  cfg = config.atelier.services.arm;
in
{
  options.atelier.services.arm = {
    enable = lib.mkEnableOption "Automatic Ripping Machine";

    domain = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional domain for Caddy reverse proxy (leave null for Tailscale-only access)";
    };

    _description = lib.mkOption {
      type = lib.types.str;
      default = "Automatic Ripping Machine";
      internal = true;
      readOnly = true;
    };

    _runtime = lib.mkOption {
      type = lib.types.str;
      default = "docker";
      internal = true;
      readOnly = true;
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      readOnly = true;
      internal = true;
    };

    devices = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "/dev/sr0" ];
      description = "Optical drive device paths to pass through to the container";
    };

    nvidiaGpu = lib.mkOption {
      type = lib.types.bool;
      default = config.hardware.nvidia.enabled or false;
      description = "Whether to pass NVIDIA GPU to the container for hardware transcoding";
    };
  };

  config = lib.mkIf cfg.enable {
    # ── Docker runtime ────────────────────────────────────────────────
    virtualisation.docker = {
      enable = true;
      autoPrune.enable = true;
    };
    virtualisation.oci-containers.backend = "docker";

    # ── User and directories ──────────────────────────────────────────
    users.users.arm = {
      isSystemUser = true;
      uid = 990;
      group = "arm";
      extraGroups = [
        "cdrom"
        "video"
        "render"
        "media"
      ];
      home = "/storage/arm";
    };
    users.groups.arm.gid = 990;

    systemd.tmpfiles.rules = [
      "d /storage/arm         0755 arm arm -"
      "d /storage/arm/config  0755 arm arm -"
      "d /storage/arm/media   2775 arm media -"
      "d /storage/arm/music   2775 arm media -"
      "d /storage/arm/logs    0755 arm arm -"
    ];

    # ── Container ─────────────────────────────────────────────────────
    virtualisation.oci-containers.containers.arm = {
      image = "automaticrippingmachine/automatic-ripping-machine:latest";
      ports = [ "${toString cfg.port}:8080" ];
      volumes = [
        "/storage/arm/config:/etc/arm/config"
        "/storage/arm/media:/home/arm/media"
        "/storage/arm/music:/home/arm/music"
        "/storage/arm/logs:/home/arm/logs"
        "/storage/arm:/home/arm"
      ];
      environment = {
        ARM_UID = toString config.users.users.arm.uid;
        ARM_GID = toString config.users.groups.arm.gid;
        TZ = config.time.timeZone;
      };
      extraOptions =
        # Optical drives
        (map (dev: "--device=${dev}:${dev}") cfg.devices)
        # SCSI generic devices (MakeMKV needs these)
        ++ [ "--device=/dev/sg0:/dev/sg0" ]
        # Privileged for udev/device access
        ++ [ "--privileged" ]
        # NVIDIA GPU passthrough
        ++ lib.optionals cfg.nvidiaGpu [
          "--gpus=all"
          "--env=NVIDIA_DRIVER_CAPABILITIES=all"
        ];
    };

    # Ensure Docker starts before the ARM container
    systemd.services.docker-arm = {
      after = [ "docker.service" ];
      requires = [ "docker.service" ];
    };

    # ── Caddy reverse proxy (optional) ────────────────────────────────
    services.caddy.virtualHosts = lib.mkIf (cfg.domain != null) {
      ${cfg.domain} = {
        extraConfig = ''
          tls {
            dns cloudflare {env.CLOUDFLARE_API_TOKEN}
          }
          header {
            Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
          }

          reverse_proxy localhost:${toString cfg.port}
        '';
      };
    };
  };
}
