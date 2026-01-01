# Control Panel - Admin dashboard for Caddy toggles
#
# Protected by Indiko OAuth, allows toggling feature flags
# that control Caddy behavior. Uses SQLite for flag storage
# and exposes a /kill-check endpoint for Caddy to query.

{ config, lib, pkgs, ... }:

let
  mkService = import ../../lib/mkService.nix;
  cfg = config.atelier.services.control;

  # Generate flags.json from Nix config
  flagsJson = pkgs.writeText "flags.json" (builtins.toJSON {
    services = lib.mapAttrs (serviceId: serviceCfg: {
      name = serviceCfg.name;
      flags = lib.mapAttrs (flagId: flagCfg: {
        name = flagCfg.name;
        description = flagCfg.description;
        paths = flagCfg.paths;
        redact = flagCfg.redact;
      }) serviceCfg.flags;
    }) cfg.flags;
  });

  baseModule = mkService {
    name = "control";
    description = "Control Panel - Admin dashboard for Caddy toggles";
    defaultPort = 3010;
    runtime = "bun";
    entryPoint = "src/index.ts";

    extraOptions = {
      flags = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submodule {
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              description = "Display name for this service";
            };
            flags = lib.mkOption {
              type = lib.types.attrsOf (lib.types.submodule {
                options = {
                  name = lib.mkOption {
                    type = lib.types.str;
                    description = "Display name for this flag";
                  };
                  description = lib.mkOption {
                    type = lib.types.str;
                    description = "Description of what this flag does";
                  };
                  paths = lib.mkOption {
                    type = lib.types.listOf lib.types.str;
                    default = [];
                    description = "URL paths this flag fully blocks";
                  };
                  redact = lib.mkOption {
                    type = lib.types.attrsOf (lib.types.listOf lib.types.str);
                    default = {};
                    description = "Map of path -> fields to redact from JSON response";
                  };
                };
              });
              default = {};
              description = "Flags for this service";
            };
          };
        });
        default = {};
        description = "Services and their flags";
        example = lib.literalExpression ''
          {
            "map.dunkirk.sh" = {
              name = "Map";
              flags = {
                "block-tracking" = {
                  name = "Block Player Tracking";
                  description = "Disable real-time player location updates";
                  paths = [ "/sse" "/tiles/world/markers/pl3xmap_players.json" ];
                  redact = {
                    "/tiles/settings.json" = [ "players" ];
                  };
                };
              };
            };
          }
        '';
      };
    };

    extraConfig = innerCfg: {
      atelier.services.control.environment = {
        INDIKO_URL = "https://indiko.dunkirk.sh";
        CLIENT_ID = "https://${innerCfg.domain}/";
        REDIRECT_URI = "https://${innerCfg.domain}/auth/callback";
        DATABASE_PATH = "${innerCfg.dataDir}/data/control.db";
        FLAGS_CONFIG = toString flagsJson;
      };

      # Data declarations for backup (SQLite database)
      atelier.services.control.data = {
        sqlite = "${innerCfg.dataDir}/data/control.db";
      };
    };
  };
in
{
  imports = [ baseModule ];
}
