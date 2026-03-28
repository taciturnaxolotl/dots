# Overpass - Personal gas price cache server

let
  mkService = import ../../lib/mkService.nix;
in

mkService {
  name = "overpass";
  description = "Overpass gas price cache server";
  defaultPort = 7878;
  runtime = "bun";

  entryPoint = "api/src/index.ts";

  extraConfig = cfg: {
    systemd.services.overpass.serviceConfig.Environment = [
      "DB_PATH=${cfg.dataDir}/data/overpass.db"
    ];

    atelier.services.overpass.data = {
      sqlite = "${cfg.dataDir}/data/overpass.db";
    };
  };
}
