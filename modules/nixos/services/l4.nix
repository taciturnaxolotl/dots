# L4 - Image CDN / Slack image optimizer
#
# Images stored in R2, but keeps local stats

{ config, lib, pkgs, ... }:

let
  mkService = import ../../lib/mkService.nix;
  baseModule = mkService {
    name = "l4";
    description = "L4 Image CDN - Slack image optimizer and R2 uploader";
    defaultPort = 3004;
    runtime = "bun";
    entryPoint = "src/index.ts";

    extraConfig = cfg: {
      # Add PUBLIC_URL and STATS_DB_PATH environment variables
      atelier.services.l4.environment = {
        PUBLIC_URL = "https://${cfg.domain}";
        STATS_DB_PATH = "${cfg.dataDir}/data/stats.db";
      };

      # Data declarations for backup (SQLite stats database)
      atelier.services.l4.data = {
        sqlite = "${cfg.dataDir}/data/stats.db";
      };
    };
  };
  cfg = config.atelier.services.l4;
in
{
  imports = [ baseModule ];
  
  # Add LD_LIBRARY_PATH for native dependencies (sharp image processing)
  config = lib.mkIf cfg.enable {
    systemd.services.l4.environment.LD_LIBRARY_PATH = "${pkgs.stdenv.cc.cc.lib}/lib";
    systemd.services.l4.path = [ pkgs.stdenv.cc.cc.lib ];
  };
}
