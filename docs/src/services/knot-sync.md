# knot-sync

Mirrors Tangled knot repositories to GitHub on a cron schedule.

This is a **custom module** — it does not use mkService. Runs as a systemd timer, not a long-running service.

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Enable knot-sync |
| `repoDir` | string | `"/home/git/did:plc:..."` | Directory containing knot git repos |
| `githubUsername` | string | `"taciturnaxolotl"` | GitHub username to mirror to |
| `secretsFile` | path | — | Agenix secrets (must contain `GITHUB_TOKEN`) |
| `logFile` | string | `"/home/git/knot-sync.log"` | Log file path |
| `interval` | string | `"*/5 * * * *"` | Cron schedule for sync |
