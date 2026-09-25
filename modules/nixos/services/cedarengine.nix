{
  config,
  lib,
  pkgs,
  ...
}:

let
  mkService = import ../../lib/mkService.nix;
  cfg = config.atelier.services.cedarengine;

  baseModule = mkService {
    name = "cedarengine";
    description = "cedarengine Cedarville directory, catalog and campus API";
    defaultPort = 3007;
    runtime = "bun";
    startCommand = "${pkgs.unstable.bun}/bin/bun start";

    extraConfig = cfg: {
      atelier.services.cedarengine.environment = {
        DATABASE_PATH = "${cfg.dataDir}/data/cedarengine.db";
        HOST = "127.0.0.1";
      };

      atelier.services.cedarengine.caddy.rateLimit = {
        enable = true;
        events = 600;
        window = "1m";
      };

      # WAL lets restic hot copy
      atelier.services.cedarengine.data = {
        sqlite = "${cfg.dataDir}/data/cedarengine.db";
        stopForBackup = false;
      };
    };
  };
in
{
  imports = [ baseModule ];

  config = lib.mkIf cfg.enable {
    systemd.services.cedarengine.path = lib.mkAfter [ pkgs.sqlite ];
  };
}
