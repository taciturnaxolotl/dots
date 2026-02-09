# Traverse - Interactive code walkthrough diagram server
#
# Uses the mkService base to provide standardized:
# - Systemd service with git deployment
# - Caddy reverse proxy
# - Automatic SQLite backup with WAL checkpoint

let
  mkService = import ../../lib/mkService.nix;
in

mkService {
  name = "traverse";
  description = "Traverse code walkthrough diagram server";
  defaultPort = 4173;
  runtime = "bun";
  entryPoint = "src/index.ts";

  extraConfig = cfg: {
    systemd.services.traverse.serviceConfig.Environment = [
      "TRAVERSE_MODE=server"
      "TRAVERSE_PORT=${toString cfg.port}"
      "TRAVERSE_DATA_DIR=${cfg.dataDir}/data"
      "TRAVERSE_SHARE_URL=https://${cfg.domain}"
    ];

    atelier.services.traverse.data = {
      sqlite = "${cfg.dataDir}/data/traverse.db";
    };
  };
}
