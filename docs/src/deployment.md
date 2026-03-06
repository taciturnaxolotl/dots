# Deployment

Two deploy paths: **infrastructure** (NixOS config changes) and **application code** (per-service repos).

## Infrastructure

Pushing to `main` triggers `.github/workflows/deploy.yaml` which runs `deploy-rs` over Tailscale to rebuild NixOS on the target machine.

```sh
# manual deploy
nix run 'github:serokell/deploy-rs' -- --remote-build --ssh-user kierank .
```

## Application Code

Each service repo has a minimal workflow calling the reusable `.github/workflows/deploy-service.yml`. On push to `main`:

1. Connects to Tailscale (`tag:deploy`)
2. SSHes as the **service user** (e.g., `cachet@terebithia`) via Tailscale SSH
3. Snapshots the SQLite DB (if `db_path` is provided)
4. `git pull` + `bun install --frozen-lockfile` + `sudo systemctl restart`
5. Health check (HTTP URL or systemd status fallback)
6. Auto-rollback on failure (restores DB snapshot + reverts to previous commit)

Per-app workflow — copy and change the `with:` values:

```yaml
name: Deploy
on:
  push:
    branches: [main]
  workflow_dispatch:
jobs:
  deploy:
    uses: taciturnaxolotl/dots/.github/workflows/deploy-service.yml@main
    with:
      service: cachet
      health_url: https://cachet.dunkirk.sh/health
      db_path: /var/lib/cachet/data/cachet.db
    secrets:
      TS_OAUTH_CLIENT_ID: ${{ secrets.TS_OAUTH_CLIENT_ID }}
      TS_OAUTH_SECRET: ${{ secrets.TS_OAUTH_SECRET }}
```

Omit `health_url` to fall back to `systemctl is-active`. Omit `db_path` for stateless services.

## mkService

`modules/lib/mkService.nix` standardizes service modules. A call to `mkService { ... }` provides:

- Systemd service with initial git clone (subsequent deploys via GitHub Actions)
- Caddy reverse proxy with TLS via Cloudflare DNS and optional rate limiting
- Data declarations (`sqlite`, `postgres`, `files`) that feed into automatic backups
- Dedicated system user with sudo for restart/stop/start (enables per-user Tailscale ACLs)
- Port conflict detection, security hardening, agenix secrets

### Adding a new service

1. Create a module in `modules/nixos/services/`
2. Enable it in `machines/terebithia/default.nix`
3. Add a deploy workflow to the app repo

See `modules/nixos/services/cachet.nix` for a minimal example.

## Machine health checks

Machines with Tailscale enabled automatically expose their hostname for reachability checks in the services manifest via `atelier.machine.tailscaleHost`. This defaults to `networking.hostName` when `services.tailscale.enable` is true.
