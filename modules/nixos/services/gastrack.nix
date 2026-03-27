# Gastrack - Personal gas price cache server

let
  mkService = import ../../lib/mkService.nix;
in

mkService {
  name = "gastrack";
  description = "Gastrack gas price cache server";
  defaultPort = 7878;
  runtime = "bun";

  entryPoint = "api/src/index.ts";

  extraConfig = cfg: {
    systemd.services.gastrack.serviceConfig.Environment = [
      "DB_PATH=${cfg.dataDir}/data/gastrack.db"
    ];

    atelier.services.gastrack.data = {
      sqlite = "${cfg.dataDir}/data/gastrack.db";
    };
  };
}
