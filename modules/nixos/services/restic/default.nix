{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.atelier.backup;
  
  # Collect all atelier services that have data declarations
  atelierServices = lib.filterAttrs (name: svc: 
    svc.enable or false && (svc.data or null) != null
  ) (config.atelier.services or {});
  
  # Check if a service has any data to backup
  hasData = svc: 
    (svc.data.sqlite or null) != null ||
    (svc.data.postgres or null) != null ||
    (svc.data.files or []) != [];
  
  # Collect services with data declarations
  servicesWithData = lib.filterAttrs (name: svc: hasData svc) atelierServices;
  
  # Also include manually registered services
  allBackups = cfg.services // (lib.mapAttrs mkAutoBackup servicesWithData);
  
  # Auto-generate backup config from service data declarations
  mkAutoBackup = name: svc: let
    data = svc.data;
    hasSqlite = data.sqlite or null != null;
    hasPostgres = data.postgres or null != null;
    
    # Collect all paths to backup
    paths = 
      (lib.optional hasSqlite (builtins.dirOf data.sqlite)) ++
      (data.files or []);
    
    # Pre-backup: handle database consistency
    preBackup = lib.concatStringsSep "\n" (
      # SQLite: checkpoint WAL then stop service
      (lib.optional hasSqlite ''
        echo "Checkpointing SQLite WAL for ${name}..."
        ${pkgs.sqlite}/bin/sqlite3 "${data.sqlite}" "PRAGMA wal_checkpoint(TRUNCATE);" || true
        echo "Stopping ${name} for backup..."
        systemctl stop ${name}
      '') ++
      # PostgreSQL: dump to file
      (lib.optional hasPostgres ''
        echo "Dumping PostgreSQL database ${data.postgres}..."
        ${pkgs.sudo}/bin/sudo -u postgres ${pkgs.postgresql}/bin/pg_dump ${data.postgres} > /tmp/${name}-pg-dump.sql
      '') ++
      # If no database but service needs to be stopped (manual override possible)
      []
    );
    
    # Post-backup: restart service
    postBackup = lib.concatStringsSep "\n" (
      (lib.optional hasSqlite ''
        echo "Restarting ${name} after backup..."
        systemctl start ${name}
      '') ++
      (lib.optional hasPostgres ''
        rm -f /tmp/${name}-pg-dump.sql
      '')
    );
    
  in {
    enable = true;
    inherit paths;
    exclude = data.exclude or [ "*.log" "node_modules" ".git" ];
    tags = [ "service:${name}" ] ++ 
      (lib.optional hasSqlite "type:sqlite") ++
      (lib.optional hasPostgres "type:postgres");
    preBackup = if preBackup != "" then preBackup else null;
    postBackup = if postBackup != "" then postBackup else null;
  };

  # Create a restic backup job for a service
  mkBackupJob = name: serviceCfg: {
    inherit (serviceCfg) paths exclude;
    
    initialize = true;
    
    # Use secrets from agenix
    environmentFile = config.age.secrets."restic/env".path;
    repositoryFile = config.age.secrets."restic/repo".path;
    passwordFile = config.age.secrets."restic/password".path;
    
    # Tags for easier filtering during restore
    extraBackupArgs = 
      (map (t: "--tag ${t}") (serviceCfg.tags or [ "service:${name}" ])) ++
      [ "--verbose" ];
    
    # Retention policy
    pruneOpts = [
      "--keep-last 3"
      "--keep-daily 7"
      "--keep-weekly 5"
      "--keep-monthly 12"
      "--tag service:${name}"  # Only prune this service's snapshots
    ];
    
    # Backup schedule (nightly at 2 AM + random delay)
    timerConfig = {
      OnCalendar = "02:00";
      RandomizedDelaySec = "2h";
      Persistent = true;
    };
    
    # Pre/post backup hooks for database consistency
    backupPrepareCommand = lib.optionalString (serviceCfg.preBackup or null != null) serviceCfg.preBackup;
    backupCleanupCommand = lib.optionalString (serviceCfg.postBackup or null != null) serviceCfg.postBackup;
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
              default = [ "*.log" "node_modules" ".git" ];
              description = "Glob patterns to exclude from backup";
            };

            tags = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [];
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
    services.restic.backups = lib.mapAttrs mkBackupJob (
      lib.filterAttrs (n: v: v.enable) allBackups
    );

    # Add restic and sqlite to system packages for manual operations
    environment.systemPackages = [ pkgs.restic pkgs.sqlite ];
  };
}
