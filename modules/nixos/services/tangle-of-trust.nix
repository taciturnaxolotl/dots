{ config, lib, pkgs, ... }:

let
  mkService = import ../../lib/mkService.nix;
  cfg = config.atelier.services.tangle-of-trust;

  pkg = pkgs.tangle-of-trust;

  baseModule = mkService {
    name = "tangle-of-trust";
    description = "Tangled trust graph visualizer";
    defaultPort = 8080;
    runtime = "custom";
    startCommand = "${pkg}/bin/tangle-ingest --db ${cfg.dataDir}/data/tangle.db --web :${toString cfg.port}";

    extraConfig = cfg: {
      systemd.services.tangle-of-trust.serviceConfig.Environment = [
        "TANGLE_STATIC_DIR=${pkg."web-dist"}"
      ];

      atelier.services.tangle-of-trust.data = {
        sqlite = "${cfg.dataDir}/data/tangle.db";
      };
    };
  };
in
{
  imports = [ baseModule ];
}
