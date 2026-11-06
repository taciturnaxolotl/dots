{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.atelier.services.knot-sync;

  syncer = pkgs.writers.writePython3 "knot-sync" {
    flakeIgnore = [ "E501" ];
  } (builtins.readFile ./knot-sync.py);

  settings = {
    KNOT_URL = cfg.knotUrl;
    OWNER_DID = cfg.ownerDid;
    GITHUB_USERNAME = cfg.githubUsername;
    EXCLUDE = lib.concatStringsSep "," cfg.exclude;
  };

  hook = pkgs.writeShellScript "knot-post-receive" ''
    set -a
    ${lib.toShellVars settings}
    . ${lib.escapeShellArg cfg.secretsFile}
    set +a
    exec ${syncer} hook
  '';
in
{
  options.atelier.services.knot-sync = {
    enable = lib.mkEnableOption "mirroring knot repositories to GitHub";

    knotUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:5555";
      description = "The knot's local HTTP listener, for repo manifests and fetching";
    };

    ownerDid = lib.mkOption {
      type = lib.types.str;
      description = "DID of the knot owner; only repos owned by this DID will be synced";
    };

    githubUsername = lib.mkOption {
      type = lib.types.str;
      default = "taciturnaxolotl";
      description = "GitHub account the mirrors live under, as github.com/<user>/<repo name>";
    };

    secretsFile = lib.mkOption {
      type = lib.types.path;
      description = "Environment file containing GITHUB_TOKEN, readable by the knot's group";
    };

    exclude = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Repo names never to mirror";
    };

    sweepInterval = lib.mkOption {
      type = lib.types.str;
      default = "6h";
      description = "How often to fast-forward every repo, for changes no push carried";
    };

    hookTimeout = lib.mkOption {
      type = lib.types.int;
      default = 60;
      description = "Seconds the knot waits on the post-receive hook before killing it";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.knot-rs = {
      path = [ pkgs.git ];
      environment = {
        KNOT_POST_RECEIVE_HOOK = "${hook}";
        KNOT_POST_RECEIVE_TIMEOUT_SECS = toString cfg.hookTimeout;
      };
    };

    systemd.services.knot-sync = {
      description = "Fast-forward every knot repository's GitHub mirror";
      after = [
        "network-online.target"
        "knot-rs.service"
      ];
      wants = [ "network-online.target" ];
      requisite = [ "knot-rs.service" ];
      path = [ pkgs.git ];
      environment = settings;
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${syncer} sweep";
        EnvironmentFile = cfg.secretsFile;
        DynamicUser = true;
        StateDirectory = "knot-sync";
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        NoNewPrivileges = true;
      };
    };

    systemd.timers.knot-sync = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "5min";
        OnUnitActiveSec = cfg.sweepInterval;
      };
    };
  };
}
