# Pumpkin - Rust-based Minecraft server
#
# Runs as a dedicated user in a data directory.
# Pumpkin generates its own TOML config files on first start.
# Subsequent management via mcrcon or direct config edits.

{ config, lib, pkgs, ... }:

let
  cfg = config.services.pumpkin;
in
{
  options.services.pumpkin = {
    enable = lib.mkEnableOption "Pumpkin Minecraft server";

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/pumpkin";
      description = "Directory for world data, config, and logs";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 25565;
      description = "TCP port for the Minecraft server";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open the server port in the firewall";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.pumpkin;
      description = "Pumpkin package to use";
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.pumpkin = {
      isSystemUser = true;
      group = "pumpkin";
      home = cfg.dataDir;
      createHome = true;
      shell = pkgs.bash;
    };

    users.groups.pumpkin = { };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0770 pumpkin pumpkin -"
    ];

    systemd.services.pumpkin = {
      description = "Pumpkin Minecraft server";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      preStart = ''
        if [ ! -f ${cfg.dataDir}/configuration.toml ]; then
          echo 'server_address = "0.0.0.0:${toString cfg.port}"' > ${cfg.dataDir}/configuration.toml
        fi
      '';

      serviceConfig = {
        Type = "simple";
        User = "pumpkin";
        Group = "pumpkin";
        WorkingDirectory = cfg.dataDir;
        ExecStart = "${cfg.package}/bin/pumpkin";
        Restart = "on-failure";
        RestartSec = "10s";
        TimeoutStopSec = "60s";

        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ReadWritePaths = [ cfg.dataDir ];
        ProtectHome = true;
        PrivateTmp = true;
      };
    };

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };
  };
}
