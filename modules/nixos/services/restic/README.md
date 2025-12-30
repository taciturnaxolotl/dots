# Restic Backup System

Per-service backup system using Restic and Backblaze B2, with automatic backup discovery from `mkService` data declarations.

## Quick Start

### 1. Create B2 Bucket

1. Go to [Backblaze B2 console](https://secure.backblaze.com/b2_buckets.htm)
2. Create a new bucket (e.g., `terebithia-backup`)
3. Create an application key with read/write access to this bucket
4. Note the Account ID, Application Key, and Bucket name

### 2. Create Agenix Secrets

```bash
cd ~/dots/secrets
mkdir -p restic

# Repository encryption password
echo "choose-a-strong-encryption-password" | agenix -e restic/password.age

# B2 credentials
cat > /tmp/restic-env << 'EOF'
B2_ACCOUNT_ID="your-account-id"
B2_ACCOUNT_KEY="your-application-key"
EOF
agenix -e restic/env.age < /tmp/restic-env
rm /tmp/restic-env

# Repository URL
echo "b2:your-bucket-name:/" | agenix -e restic/repo.age
```

### 3. Add Secrets to Machine Config

```nix
age.secrets = {
  "restic/env".file = ../../secrets/restic/env.age;
  "restic/repo".file = ../../secrets/restic/repo.age;
  "restic/password".file = ../../secrets/restic/password.age;
};
```

### 4. Enable Backup System

```nix
atelier.backup.enable = true;
```

### 5. Deploy and Verify

```bash
deploy .#terebithia

# Check timers are active
ssh terebithia 'systemctl list-timers | grep restic'
```

## Service Integration

### Automatic (mkService)

Services using `mkService` with `data.*` declarations get automatic backup:

```nix
# In your service module
mkService {
  name = "myapp";
  # ...
  extraConfig = cfg: {
    atelier.services.myapp.data = {
      sqlite = "${cfg.dataDir}/data/app.db";  # Auto WAL checkpoint + stop/start
      files = [ "${cfg.dataDir}/uploads" ];    # Just backed up, no hooks
    };
  };
}
```

The backup system automatically:
- Checkpoints SQLite WAL before backup
- Stops the service during backup
- Restarts after completion
- Tags snapshots with `service:myapp` and `type:sqlite`

### Manual Registration

For services not using `mkService`:

```nix
atelier.backup.services.myservice = {
  paths = [ "/var/lib/myservice" ];
  exclude = [ "*.log" "cache/*" ];
  preBackup = "systemctl stop myservice";
  postBackup = "systemctl start myservice";
};
```

## CLI Usage

The `atelier-backup` command provides an interactive TUI:

```bash
atelier-backup              # Interactive menu
atelier-backup status       # Show backup status for all services
atelier-backup list         # Browse snapshots
atelier-backup backup       # Trigger manual backup
atelier-backup restore      # Interactive restore wizard
atelier-backup dr           # Disaster recovery mode
```

See `man atelier-backup` for full documentation.

## Backup Schedule

- **Time**: 02:00 AM daily
- **Random delay**: 0-2 hours (spreads load across services)
- **Retention**:
  - Last 3 snapshots
  - 7 daily backups
  - 5 weekly backups
  - 12 monthly backups

## Disaster Recovery

On a fresh NixOS install:

1. Rebuild from flake: `nixos-rebuild switch --flake .#hostname`
2. Run: `atelier-backup dr`
3. All services restored from latest snapshots

A manifest at `/etc/atelier/backup-manifest.json` tracks all configured backups.

## Systemd Units

Each service gets:
- Timer: `restic-backups-<service>.timer`
- Service: `restic-backups-<service>.service`

```bash
# Check timer status
systemctl list-timers | grep restic

# View backup logs
journalctl -u restic-backups-<service>.service

# Manual backup trigger
systemctl start restic-backups-<service>.service
```

## Testing Backups

Always verify backups work before relying on them:

```bash
# Restore to /tmp for inspection
atelier-backup restore
# → Select service → Select snapshot → "Inspect (restore to /tmp)"

# Check restored files
ls -la /tmp/restore-myservice-*/
```
