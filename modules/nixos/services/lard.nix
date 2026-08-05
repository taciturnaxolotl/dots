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

      multiUser = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Give every authenticated identity its own isolated store under
          dataDir/data/users, instead of pooling every caller into one memory.
          Needs authMode = "oauth", since that is what puts an identity on a
          request.
        '';
      };

      primaryUser = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = ''
          Identity owning requests that carry no OAuth identity. On the first
          multi-user boot, an existing single-user database and memory
          directory are moved into this user's tenant, so turning multiUser on
          does not strand the memory accumulated before the switch.
        '';
      };
    };

    extraConfig =
      cfg:
      let
        # One definition of where the data lives, shared by the service and by
        # the backup job. Two copies of these paths would drift, and the way
        # you would find out is a backup of the wrong directory.
        storage = {
          LARD_DB = "${cfg.dataDir}/data/lard.db";
          LARD_MEMORY_DIR = "${cfg.dataDir}/data/memory";
          LARD_DATA_DIR = "${cfg.dataDir}/data/users";
          LARD_MULTI_USER = lib.boolToString cfg.multiUser;
        };

        # The staging directory lard snapshots into. It is what restic
        # archives, so restoring reproduces this path and not the live one:
        # see the postBackup note and `lard restore`.
        stageDir = "${cfg.dataDir}/backup";

        storageEnv = lib.concatStringsSep " " (
          lib.mapAttrsToList (k: v: "${k}=${lib.escapeShellArg v}") storage
        );
      in
      {
        atelier.services.lard.environment = storage // {
          LARD_ADDR = ":${toString cfg.port}";
          LARD_AUTH = cfg.authMode;
          LARD_AUTH_SERVER = cfg.authServer;
          LARD_PUBLIC_URL = "https://${cfg.domain}";
          LARD_OAUTH_CLIENT_IDS = lib.concatStringsSep "," cfg.allowedClientIds;
          LARD_OAUTH_USERS = lib.concatStringsSep "," cfg.allowedUsers;
        }
        // lib.optionalAttrs (cfg.collectorClientId != "") {
          LARD_COLLECTOR_CLIENT_ID = cfg.collectorClientId;
        }
        // lib.optionalAttrs (cfg.primaryUser != "") {
          LARD_PRIMARY_USER = cfg.primaryUser;
        };

        assertions = [
          {
            assertion = !cfg.multiUser || cfg.authMode == "oauth" || cfg.primaryUser != "";
            message = ''
              atelier.services.lard: multiUser keys memory by the identity on
              the token, and only authMode = "oauth" produces one. With
              authMode = "${cfg.authMode}" every request would fall back to
              primaryUser, which is unset, so lard would refuse every request.
            '';
          }
          {
            assertion = !cfg.multiUser || cfg.primaryUser == "" || lib.elem cfg.primaryUser cfg.allowedUsers || cfg.allowedUsers == [ ];
            message = ''
              atelier.services.lard: primaryUser "${cfg.primaryUser}" is not in
              allowedUsers, so the tenant that inherits the pre-multi-user
              database is one nobody can ever authenticate into. Its memory
              would look empty with no error anywhere.
            '';
          }
        ];

        # lard is not backed up through the generic `data` path. That path
        # stops the service so a plain file copy of a live SQLite database is
        # safe, which costs a nightly outage on the service every agent session
        # talks to, and only ever checkpoints one database no matter how many
        # tenants exist. `lard backup` uses VACUUM INTO instead: a consistent
        # copy of every store, taken while the server keeps serving.
        atelier.backup.services.lard = {
          enable = true;
          paths = [ stageDir ];
          tags = [
            "service:lard"
            "type:sqlite"
          ];
          preBackup = ''
            rm -rf ${stageDir}
            ${storageEnv} ${pkgs.lard}/bin/lard backup ${stageDir}
          '';
          # The staging copy is a second copy of every memory on disk. Keep it
          # only for as long as restic is reading it.
          postBackup = ''
            rm -rf ${stageDir}
          '';
        };
      };
  };
in
{
  imports = [ baseModule ];
}
