{
  config,
  lib,
  pkgs,
  ...
}:

let
  mkService = import ../../lib/mkService.nix;

  baseModule = mkService {
    name = "lard";
    description = "Lard — memory layer for homelab LLM sessions";
    defaultPort = 7477;
    runtime = "custom";
    startCommand = "${pkgs.lard}/bin/lard";

    extraOptions = {
      authMode = lib.mkOption {
        type = lib.types.enum [
          "none"
          "token"
          "oauth"
        ];
        default = "oauth";
        description = "Authentication mode for lard";
      };

      authServer = lib.mkOption {
        type = lib.types.str;
        default = "https://indiko.dunkirk.sh";
        description = "Authorization server URL (oauth mode)";
      };

      allowedClientIds = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "OAuth client IDs allowed to access lard";
      };

      allowedUsers = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "User identity URLs allowed to access lard";
      };

      collectorClientId = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "OAuth client ID the server publishes for edge collectors to use";
      };
    };

    extraConfig = cfg: {
      atelier.services.lard.environment = {
        LARD_ADDR = ":${toString cfg.port}";
        LARD_DB = "${cfg.dataDir}/data/lard.db";
        LARD_MEMORY_DIR = "${cfg.dataDir}/data/memory";
        LARD_AUTH = cfg.authMode;
        LARD_AUTH_SERVER = cfg.authServer;
        LARD_PUBLIC_URL = "https://${cfg.domain}";
        LARD_OAUTH_CLIENT_IDS = lib.concatStringsSep "," cfg.allowedClientIds;
        LARD_OAUTH_USERS = lib.concatStringsSep "," cfg.allowedUsers;
      }
      // lib.optionalAttrs (cfg.collectorClientId != "") {
        LARD_COLLECTOR_CLIENT_ID = cfg.collectorClientId;
      };

      atelier.services.lard.data = {
        sqlite = "${cfg.dataDir}/data/lard.db";
        files = [ "${cfg.dataDir}/data/memory" ];
      };
    };
  };
in
{
  imports = [ baseModule ];
}
