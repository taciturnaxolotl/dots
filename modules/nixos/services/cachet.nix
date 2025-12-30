# Cachet - Slack emoji/profile cache service
#
# Uses the mkService base to provide standardized:
# - Systemd service with git deployment
# - Caddy reverse proxy
# - Automatic SQLite backup with WAL checkpoint

let
  mkService = import ../../lib/mkService.nix;
in

mkService {
  name = "cachet";
  description = "Cachet Slack emoji/profile cache";
  defaultPort = 3000;
  runtime = "bun";
  entryPoint = "src/index.ts";

  extraConfig = cfg: {
    # Set DATABASE_PATH environment variable
    systemd.services.cachet.serviceConfig.Environment = [
      "DATABASE_PATH=${cfg.dataDir}/data/cachet.db"
    ];

    # Data declarations for automatic backup
    atelier.services.cachet.data = {
      sqlite = "${cfg.dataDir}/data/cachet.db";
    };
  };
}
