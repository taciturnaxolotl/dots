{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.atelier.services.knot-sync;

  syncer = pkgs.writers.writePython3 "knot-sync" {
    libraries = [
      pkgs.python3Packages.cbor2
      pkgs.python3Packages.websockets
    ];
    flakeIgnore = [ "E501" ];
  } (builtins.readFile ./knot-sync.py);
in
{
  options.atelier.services.knot-sync = {
    enable = lib.mkEnableOption "mirroring knot repositories to GitHub";

    knotUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:5555";
      description = "The knot's local HTTP listener, for its firehose and for fetching";
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
      description = "Environment file containing GITHUB_TOKEN";
    };

    exclude = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Repo names never to mirror";
    };

    sweepInterval = lib.mkOption {
      type = lib.types.int;
      default = 6 * 3600;
      description = "Seconds between full sweeps of every repo, on top of the event-driven syncs";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.knot-sync = {
      description = "Mirror knot repositories to GitHub";
      after = [
        "network-online.target"
        "knot-rs.service"
      ];
      wants = [ "network-online.target" ];
      bindsTo = [ "knot-rs.service" ];
      wantedBy = [ "knot-rs.service" ];
      path = [ pkgs.git ];
      environment = {
        KNOT_URL = cfg.knotUrl;
        OWNER_DID = cfg.ownerDid;
        GITHUB_USERNAME = cfg.githubUsername;
        EXCLUDE = lib.concatStringsSep "," cfg.exclude;
        SWEEP_SECS = toString cfg.sweepInterval;
      };
      serviceConfig = {
        ExecStart = syncer;
        EnvironmentFile = cfg.secretsFile;
        DynamicUser = true;
        StateDirectory = "knot-sync";
        Restart = "always";
        RestartSec = 10;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        NoNewPrivileges = true;
      };
    };
  };
}
