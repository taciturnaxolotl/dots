% ATELIER-BACKUP(1) atelier-backup 1.0
% Kieran Klukas
% December 2024

# NAME

atelier-backup - interactive backup management for atelier services

# SYNOPSIS

**atelier-backup** [*COMMAND*]

**atelier-backup** **status**

**atelier-backup** **list**

**atelier-backup** **backup**

**atelier-backup** **restore**

**atelier-backup** **dr**

# DESCRIPTION

**atelier-backup** is an interactive CLI for managing restic backups of atelier services. It provides a gum-powered TUI for browsing snapshots, triggering backups, restoring data, and performing disaster recovery.

When run without arguments, an interactive menu is displayed.

# COMMANDS

**status**
: Show the backup status for all configured services, including the date of the most recent snapshot.

**list**
: Interactively select a service and browse its available snapshots.

**backup**
: Trigger a manual backup for a selected service or all services.

**restore**
: Interactive restore wizard. Select a service, choose a snapshot, and restore either to /tmp for inspection or in-place (with service stop/start).

**dr**, **disaster-recovery**
: Full disaster recovery mode. Restores the latest snapshot for ALL services. Only use on a fresh NixOS install after rebuilding from the flake.

# OPTIONS

**-h**, **--help**
: Display usage information and exit.

# RESTORE MODES

When restoring, you can choose between two modes:

**Inspect (restore to /tmp)**
: Restores the snapshot to /tmp/restore-SERVICE-SNAPSHOT for inspection. Safe and non-destructive.

**In-place (DANGEROUS)**
: Stops the service, restores directly to the original paths, and restarts the service. Use with caution.

# DISASTER RECOVERY

The **dr** command is designed for full server recovery:

1. Rebuild NixOS from the flake: `nixos-rebuild switch --flake .#hostname`
2. Run: `atelier-backup dr`
3. The CLI restores the latest snapshot for each service
4. Services are started automatically after restore

A backup manifest is stored at **/etc/atelier/backup-manifest.json** containing metadata about all configured backups.

# EXAMPLES

Interactive menu:
```
$ atelier-backup
```

Check backup status for all services:
```
$ atelier-backup status
```

Browse snapshots for a service:
```
$ atelier-backup list
```

Trigger manual backup:
```
$ atelier-backup backup
```

Restore a service from backup:
```
$ atelier-backup restore
```

Full disaster recovery:
```
$ atelier-backup dr
```

# FILES

**/etc/atelier/backup-manifest.json**
: Generated manifest containing backup configuration for all services.

**/run/agenix/restic/***
: Agenix-managed secrets for restic (env, repo, password).

# BACKUP SCHEDULE

Services are backed up nightly at 02:00 with a randomized delay of up to 2 hours to spread load. Backups are triggered via systemd timers:

- `restic-backups-SERVICE.timer`
- `restic-backups-SERVICE.service`

# RETENTION POLICY

Snapshots are retained according to:

- Last 3 snapshots
- 7 daily backups
- 5 weekly backups
- 12 monthly backups

# SEE ALSO

**restic**(1), **systemctl**(1)

Restic documentation: https://restic.readthedocs.io/

# BUGS

Report bugs at: https://github.com/taciturnaxolotl/dots/issues

# AUTHORS

Kieran Klukas <kierank@dunkirk.sh>
