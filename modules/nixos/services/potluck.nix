{
  config,
  lib,
  pkgs,
  ...
}:

let
  mkService = import ../../lib/mkService.nix;
  cfg = config.atelier.services.potluck;

  baseModule = mkService {
    name = "potluck";
    description = "Potluck — pooled pioneer.ai chat frontend";
    defaultPort = 8090;
    runtime = "custom";
    startCommand = "${pkgs.potluck}/bin/server --auto-migrate";

    extraConfig = cfg: {
      atelier.services.potluck.environment = {
        POTLUCK_HTTP_LISTEN_ADDR = ":${toString cfg.port}";
        POTLUCK_DB = "${cfg.dataDir}/data/potluck.db";
        POTLUCK_ENVIRONMENT = "production";
        POTLUCK_BASE_URL = "https://potluck.dunkirk.sh";
      };

      atelier.services.potluck.data = {
        sqlite = "${cfg.dataDir}/data/potluck.db";
      };
    };
  };
in
{
  imports = [ baseModule ];
}
