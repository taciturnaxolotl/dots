{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.atelier.backup;

  # Collect all atelier services that have data declarations
  atelierServices = lib.filterAttrs (name: svc: svc.enable or false && (svc.data or null) != null) (
    config.atelier.services or { }
  );

  # Check if a service has any data to backup
  hasData =
    svc:
    (svc.data.sqlite or null) != null
    || (svc.data.postgres or null) != null
    || (svc.data.files or [ ]) != [ ];

  # Collect services with data declarations
  servicesWithData = lib.filterAttrs (name: svc: hasData svc) atelierServices;

  # Also include manually registered services
  allBackups = cfg.services // (lib.mapAttrs mkAutoBackup servicesWithData);

  # Auto-generate backup config from service data declarations
  mkAutoBackup =
    name: svc:
    let
      data = svc.data;
      hasSqlite = data.sqlite or null != null;
      hasPostgres = data.postgres or null != null;

      # Collect all paths to backup
      paths = (lib.optional hasSqlite (builtins.dirOf data.sqlite)) ++ (data.files or [ ]);

      # Whether to stop service during backup (default true, can opt out for online-safe DBs)
      stopForBackup = data.stopForBackup or true;

      # Pre-backup: handle database consistency
      preBackup = lib.concatStringsSep "\n" (
        # SQLite: checkpoint WAL, optionally stop service
        (lib.optional hasSqlite (
          ''
            echo "Checkpointing SQLite WAL for ${name}..."
            ${pkgs.sqlite}/bin/sqlite3 "${data.sqlite}" "PRAGMA wal_checkpoint(TRUNCATE);" || true
          ''
          + lib.optionalString stopForBackup ''
            echo "Stopping ${name} for backup..."
            systemctl stop ${name}
          ''
        ))
        ++
          # PostgreSQL: dump to file
          (lib.optional hasPostgres ''
            echo "Dumping PostgreSQL database ${data.postgres}..."
            ${pkgs.sudo}/bin/sudo -u postgres ${pkgs.postgresql}/bin/pg_dump ${data.postgres} > /tmp/${name}-pg-dump.sql
          '')
        ++
          # If no database but service needs to be stopped (manual override possible)
          [ ]
      );

      # Post-backup: restart service (only if we stopped it)
      postBackup = lib.concatStringsSep "\n" (
        (lib.optional (hasSqlite && stopForBackup) ''
          echo "Restarting ${name} after backup..."
          systemctl start ${name}
        '')
        ++ (lib.optional hasPostgres ''
          rm -f /tmp/${name}-pg-dump.sql
        '')
      );

    in
    {
      enable = true;
      inherit paths;
      exclude =
        data.exclude or [
          "*.log"
          "node_modules"
          ".git"
        ];
      tags = [
        "service:${name}"
      ]
      ++ (lib.optional hasSqlite "type:sqlite")
      ++ (lib.optional hasPostgres "type:postgres");
      preBackup = if preBackup != "" then preBackup else null;
      postBackup = if postBackup != "" then postBackup else null;
    };

  # Backup jobs that should actually run
  enabledBackups = lib.filterAttrs (n: v: v.enable) allBackups;

  # Create a restic backup job for a service
  mkBackupJob = name: serviceCfg: {
    inherit (serviceCfg) paths exclude;

    initialize = true;

    # Use secrets from agenix
    environmentFile = config.age.secrets."restic/env".path;
    repositoryFile = config.age.secrets."restic/repo".path;
    passwordFile = config.age.secrets."restic/password".path;

    # Tags for easier filtering during restore
    extraBackupArgs = (map (t: "--tag ${t}") (serviceCfg.tags or [ "service:${name}" ])) ++ [
      "--verbose"
    ];

    # Prune is handled by separate weekly restic-prune-<name> units, so
    # nightly backups don't also fire a prune storm. Empty pruneOpts tells the
    # upstream module to skip the inline `forget --prune` step entirely.
    pruneOpts = [ ];

    # Backup schedule (nightly at 2 AM + random delay)
    timerConfig = {
      OnCalendar = "02:00";
      RandomizedDelaySec = "2h";
      Persistent = true;
    };

    # Pre/post backup hooks for database consistency
    backupPrepareCommand = lib.optionalString (
      serviceCfg.preBackup or null != null
    ) serviceCfg.preBackup;
    backupCleanupCommand = lib.optionalString (
      serviceCfg.postBackup or null != null
    ) serviceCfg.postBackup;
  };

in
{
  imports = [ ./cli.nix ];

  options.atelier.backup = {
    enable = lib.mkEnableOption "Restic backup system";

    # Manual service registration (for services not using mkService)
    services = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Enable backups for this service";
            };

            paths = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              description = "Paths to back up";
            };

            exclude = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [
                "*.log"
                "node_modules"
                ".git"
              ];
              description = "Glob patterns to exclude from backup";
            };

            tags = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Tags to apply to snapshots";
            };

            preBackup = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Command to run before backup";
            };

            postBackup = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Command to run after backup";
            };
          };
        }
      );
      default = { };
      description = "Per-service backup configurations (manual registration)";
    };
  };

  config = lib.mkIf cfg.enable {
    # Ensure secrets are defined
    assertions = [
      {
        assertion = config.age.secrets ? "restic/env";
        message = "atelier.backup requires age.secrets.\"restic/env\" to be defined";
      }
      {
        assertion = config.age.secrets ? "restic/repo";
        message = "atelier.backup requires age.secrets.\"restic/repo\" to be defined";
      }
      {
        assertion = config.age.secrets ? "restic/password";
        message = "atelier.backup requires age.secrets.\"restic/password\" to be defined";
      }
    ];

    # Create restic backup jobs for each service (auto + manual)
    services.restic.backups = lib.mapAttrs mkBackupJob enabledBackups;

    # Scattered weekly prune: one oneshot service + timer per backup, each
    # pinned to a day-of-week derived from the service name so all 17 services
    # don't prune (and hammer B2 Class B transactions) at the same time.
    systemd.services = lib.mapAttrs' (
      name: _:
      lib.nameValuePair "restic-prune-${name}" {
        description = "Restic forget/prune for ${name}";
        serviceConfig = {
          Type = "oneshot";
          EnvironmentFile = config.age.secrets."restic/env".path;
        };
        script = ''
          ${pkgs.restic}/bin/restic \
            --repository-file ${config.age.secrets."restic/repo".path} \
            --password-file ${config.age.secrets."restic/password".path} \
            forget --prune --verbose \
            --keep-last 3 --keep-daily 7 --keep-weekly 5 --keep-monthly 12 \
            --tag service:${name}
        '';
      }
    ) enabledBackups;

    systemd.timers =
      let
        backupNames = lib.attrNames enabledBackups;
        days = [
          "Mon"
          "Tue"
          "Wed"
          "Thu"
          "Fri"
          "Sat"
          "Sun"
        ];
      in
      lib.mapAttrs' (
        name: _:
        let
          idx = lib.lists.findFirstIndex (n: n == name) 0 backupNames;
          day = builtins.elemAt days (lib.mod idx 7);
        in
        lib.nameValuePair "restic-prune-${name}" {
          description = "Weekly restic prune for ${name} (${day})";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = "${day} *-*-* 03:00:00";
            RandomizedDelaySec = "2h";
            Persistent = true;
          };
        }
      ) enabledBackups;

    # Add restic and sqlite to system packages for manual operations
    environment.systemPackages = [
      pkgs.restic
      pkgs.sqlite
    ];
  };
}
