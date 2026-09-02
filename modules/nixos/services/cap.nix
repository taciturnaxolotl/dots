# Cap - self-hosted proof-of-work captcha server
#
# Two containers on their own docker network: cap itself, and the valkey it
# keeps challenges and site keys in. Valkey's data is bind-mounted rather than
# living in a docker volume so the backup job can reach it by path.
#
# Site keys are minted in cap's admin UI at https://<domain>, signed in with
# the ADMIN_KEY from adminKeyFile.

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.atelier.services.cap;
  network = "cap";
in
{
  options.atelier.services.cap = {
    enable = lib.mkEnableOption "Cap captcha server";

    domain = lib.mkOption {
      type = lib.types.str;
      description = "Domain to serve cap on";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3013;
      description = "Host port the cap container publishes on loopback";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/cap";
      description = "Directory to store cap data";
    };

    adminKeyFile = lib.mkOption {
      type = lib.types.path;
      description = "Environment file defining ADMIN_KEY for the cap admin UI";
    };

    _description = lib.mkOption {
      type = lib.types.str;
      default = "Cap proof-of-work captcha server";
      internal = true;
      readOnly = true;
    };

    _runtime = lib.mkOption {
      type = lib.types.str;
      default = "docker";
      internal = true;
      readOnly = true;
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.docker.enable = true;
    virtualisation.oci-containers.backend = "docker";

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 root root -"
      "d ${cfg.dataDir}/valkey 0750 root root -"
    ];

    # oci-containers attaches to networks but never creates them, and a missing
    # network fails the container at start rather than at switch time.
    systemd.services."docker-network-${network}" = {
      wantedBy = [ "multi-user.target" ];
      after = [ "docker.service" ];
      requires = [ "docker.service" ];
      before = [
        "docker-cap.service"
        "docker-cap-valkey.service"
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        ${config.virtualisation.docker.package}/bin/docker network inspect ${network} >/dev/null 2>&1 \
          || ${config.virtualisation.docker.package}/bin/docker network create ${network}
      '';
    };

    virtualisation.oci-containers.containers = {
      cap-valkey = {
        image = "valkey/valkey:9-alpine";
        volumes = [ "${cfg.dataDir}/valkey:/data" ];
        cmd = [
          "valkey-server"
          "--save"
          "60"
          "1"
          "--loglevel"
          "warning"
          "--maxmemory-policy"
          "noeviction"
        ];
        networks = [ network ];
      };

      cap = {
        image = "tiago2/cap:latest";
        ports = [ "127.0.0.1:${toString cfg.port}:3000" ];
        environment.REDIS_URL = "redis://cap-valkey:6379";
        environmentFiles = [ cfg.adminKeyFile ];
        dependsOn = [ "cap-valkey" ];
        networks = [ network ];
      };
    };

    services.caddy.virtualHosts.${cfg.domain} = {
      extraConfig = ''
        tls {
          dns cloudflare {env.CLOUDFLARE_API_TOKEN}
        }

        reverse_proxy localhost:${toString cfg.port}
      '';
    };

    # Site keys and secrets live in valkey, so losing it means every embedded
    # widget points at a key that no longer exists.
    atelier.backup.services.cap = {
      enable = true;
      paths = [ "${cfg.dataDir}/valkey" ];
      tags = [
        "service:cap"
        "type:valkey"
      ];
    };
  };
}
