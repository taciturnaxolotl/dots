# Automatic Ripping Machine (ARM) — optical disc ripper
#
# Runs the official ARM Docker image with optical drive passthrough.
# Rips DVDs/Blu-rays/CDs and outputs to /storage/media for Jellyfin.
# Expects two secrets in prattle config:
#   age.secrets.arm-tmdb  → TMDB API key
#   age.secrets.arm-makemkv → MakeMKV permanent key

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.atelier.services.arm;

  armWrapper = pkgs.writeShellScript "arm-docker-wrapper" ''
    set -euo pipefail
    DEVNAME="$1"
    if [[ -z "''${DEVNAME}" ]]; then
      echo "Usage: arm-docker-wrapper <device>" | ${pkgs.util-linux}/bin/logger -t ARM -s
      exit 1
    fi
    if [[ ! -b "''${DEVNAME}" && -b "/dev/''${DEVNAME}" ]]; then
      DEVNAME="/dev/''${DEVNAME}"
    fi

    sleep 5
    eval "$(${pkgs.systemd}/bin/udevadm info --query=env --export "''${DEVNAME}" 2>/dev/null)" || true

    local_disctype=""
    if [[ "''${ID_CDROM_MEDIA_DVD:-}" == "1" ]]; then
      disctype="dvd=1"
    elif [[ "''${ID_CDROM_MEDIA_BD:-}" == "1" ]]; then
      disctype="bd=1"
    elif [[ -n "''${ID_CDROM_MEDIA_TRACK_COUNT_AUDIO:-}" ]]; then
      disctype="cd=1"
    else
      disctype="unknown=1"
    fi

    label_flag=""
    if [[ -n "''${ID_FS_LABEL:-}" ]]; then
      label_flag="-l ID_FS_LABEL=''${ID_FS_LABEL}"
    fi

    echo "Starting ARM rip on ''${DEVNAME} (type: ''${disctype})" | ${pkgs.util-linux}/bin/logger -t ARM -s
    ${config.virtualisation.docker.package}/bin/docker exec -i \
      -u "${toString config.users.users.arm.uid}" \
      -w /home/arm \
      arm \
      python3 /opt/arm/arm/ripper/main.py \
        -d "''${DEVNAME}" -t "''${disctype}" ''${label_flag} \
      | ${pkgs.util-linux}/bin/logger -t ARM -s
  '';
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

    tmdbApiKey = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "TMDB API key for metadata lookups";
    };

    makemkvKey = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "MakeMKV permanent registration key";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.kernelModules = [ "sg" ];

    virtualisation.docker = {
      enable = true;
      autoPrune.enable = true;
    };
    virtualisation.oci-containers.backend = "docker";

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
        (map (dev: "--device=${dev}:${dev}") cfg.devices)
        ++ [ "--privileged" ]
        ++ lib.optionals cfg.nvidiaGpu [
          "--gpus=all"
          "--env=NVIDIA_DRIVER_CAPABILITIES=all"
        ];
    };

    systemd.services.docker-arm = {
      after = [ "docker.service" ];
      requires = [ "docker.service" ];
    };

    # Write arm.yaml with keys and config into the container volume
    systemd.services.arm-config = {
      description = "Generate ARM configuration";
      wantedBy = [ "multi-user.target" ];
      before = [ "docker-arm.service" ];
      serviceConfig.Type = "oneshot";
      script = ''
        mkdir -p /storage/arm/config
        cat > /storage/arm/config/arm.yaml << 'EOF'
        METADATA_PROVIDER: "tmdb"
        TMDB_API_KEY: "${cfg.tmdbApiKey}"
        MAKEMKV_PERMA_KEY: "${cfg.makemkvKey}"
        MANUAL_WAIT: false
        RIPMETHOD: "mkv"
        RIPMETHOD_DVD: "mkv"
        SKIP_TRANSCODE: false
        EJECT_WHEN_DONE: false
        COMPLETED_PATH: "/home/arm/media/completed/"
        LOGPATH: "/home/arm/logs/"
        LOGLIFE: 7
        SET_MEDIA_OWNER: false
        CHMOD_VALUE: 777
        SET_MEDIA_PERMISSIONS: false
        EOF
      '';
    };

    services.udev.extraRules = ''
      KERNEL=="sr[0-9]", ACTION=="change", SUBSYSTEM=="block", ENV{ID_CDROM_MEDIA_STATE}!="blank", RUN+="${armWrapper} %k"
    '';

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
