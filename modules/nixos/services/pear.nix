{ config, lib, pkgs, ... }:

let
  mkService = import ../../lib/mkService.nix;
  cfg = config.atelier.services.pear;

  baseModule = mkService {
    name = "pear";
    description = "Pear recipe extractor and viewer";
    defaultPort = 7879;
    runtime = "custom";
    startCommand = "${pkgs.pear}/bin/pear --port ${toString cfg.port} --db ${cfg.dataDir}/data/pear.db";

    extraConfig = cfg: {
      atelier.services.pear.environment = {
        BASE_URL = "https://${cfg.domain}";
        FLARESOLVERR_URL = "http://localhost:8191/v1";
      };

      atelier.services.pear.data = {
        sqlite = "${cfg.dataDir}/data/pear.db";
      };
    };
  };
in
{
  imports = [ baseModule ];
}
