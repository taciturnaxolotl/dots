# Canvas MCP - Model Context Protocol server for Canvas LMS
#
# Uses the mkService base to provide standardized:
# - Systemd service with git deployment
# - Caddy reverse proxy
# - Automatic SQLite backup with WAL checkpoint

let
  mkService = import ../../lib/mkService.nix;
in

mkService {
  name = "canvas-mcp";
  description = "Canvas MCP server for Claude Desktop";
  defaultPort = 3006;
  runtime = "bun";
  entryPoint = "src/index.ts";

  extraConfig = cfg: {
    # Set environment variables
    systemd.services.canvas-mcp.serviceConfig.Environment = [
      "DATABASE_PATH=${cfg.dataDir}/data/canvas-mcp.db"
      "BASE_URL=https://${cfg.domain}"
    ];

    # Load secrets from agenix if configured
    systemd.services.canvas-mcp.serviceConfig.EnvironmentFile = cfg.secretsFile;

    # Data declarations for automatic backup
    atelier.services.canvas-mcp.data = {
      sqlite = "${cfg.dataDir}/data/canvas-mcp.db";
    };
  };
}
