# HN Alerts - Hacker News monitoring service
#
# Has a database that needs backup

{ config, lib, pkgs, ... }:

let
  mkService = import ../../lib/mkService.nix;
  baseModule = mkService {
    name = "hn-alerts";
    description = "HN Alerts Hacker News monitoring service";
    defaultPort = 3001;
    runtime = "bun";
    startCommand = "${pkgs.unstable.bun}/bin/bun start";

    extraConfig = cfg: {
      # Data declarations for automatic backup
      # App uses ./local.db relative to app dir by default
      atelier.services.hn-alerts.data = {
        sqlite = "${cfg.dataDir}/app/local.db";
      };
    };
  };
  cfg = config.atelier.services.hn-alerts;
in
{
  imports = [ baseModule ];

  # Add db:push to preStart (after the base preStart runs bun install)
  config = lib.mkIf cfg.enable {
    systemd.services.hn-alerts.preStart = lib.mkAfter ''
      echo "Initializing database..."
      cd ${cfg.dataDir}/app
      ${pkgs.unstable.bun}/bin/bun run db:push || true
    '';
  };
}
