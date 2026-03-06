# Backups

Services are automatically backed up nightly using restic to Backblaze B2. Backup targets are auto-discovered from `data.sqlite`/`data.postgres`/`data.files` declarations in mkService modules.

## Schedule

- **Time:** 02:00 AM daily
- **Random delay:** 0–2 hours (spreads load across services)
- **Retention:** 3 snapshots, 7 daily, 5 weekly, 12 monthly

## CLI

The `atelier-backup` command provides an interactive TUI:

```bash
sudo atelier-backup              # Interactive menu
sudo atelier-backup status       # Show backup status for all services
sudo atelier-backup list         # Browse snapshots
sudo atelier-backup backup       # Trigger manual backup
sudo atelier-backup restore      # Interactive restore wizard
sudo atelier-backup dr           # Disaster recovery mode
```

## Service integration

### Automatic (mkService)

Services using `mkService` with `data.*` declarations get automatic backup:

```nix
mkService {
  name = "myapp";
  extraConfig = cfg: {
    atelier.services.myapp.data = {
      sqlite = "${cfg.dataDir}/data/app.db";  # Auto WAL checkpoint + stop/start
      files = [ "${cfg.dataDir}/uploads" ];    # Just backed up, no hooks
    };
  };
}
```

The backup system automatically checkpoints SQLite WAL, stops the service during backup, and restarts after completion.

### Manual registration

For services not using `mkService`:

```nix
atelier.backup.services.myservice = {
  paths = [ "/var/lib/myservice" ];
  exclude = [ "*.log" "cache/*" ];
  preBackup = "systemctl stop myservice";
  postBackup = "systemctl start myservice";
};
```

## Disaster recovery

On a fresh NixOS install:

1. Rebuild from flake: `nixos-rebuild switch --flake .#hostname`
2. Run: `sudo atelier-backup dr`
3. All services restored from latest snapshots

## Setup

1. Create a B2 bucket and application key
2. Create agenix secrets for `restic/password`, `restic/env`, `restic/repo`
3. Enable: `atelier.backup.enable = true;`

See [modules/nixos/services/restic/README.md](https://github.com/taciturnaxolotl/dots/blob/main/modules/nixos/services/restic/README.md) for full setup details.
