# Deployment

Two deploy paths: **infrastructure** (NixOS config changes) and **application code** (per-service repos).

## Infrastructure

Pushing to `main` triggers `.github/workflows/deploy.yaml` which runs `deploy-rs` over Tailscale to rebuild NixOS on the target machine.

```sh
# From the dev shell (preferred)
nix develop
deploy .#terebithia
deploy .#prattle

# Manual one-off
nix run 'github:serokell/deploy-rs' -- --remote-build --ssh-user kierank .#terebithia
```

Builds happen on the target machine (`--remote-build`), so CI only needs Nix and network access.

## Application Code

Each service repo has a minimal workflow calling the reusable `.github/workflows/deploy-service.yml`. On push to `main`:

1. Connects to Tailscale (`tag:deploy`)
2. SSHes as the **service user** (e.g., `cachet@terebithia`) via Tailscale SSH
3. Snapshots the SQLite DB (if `db_path` is provided)
4. `git pull` + `bun install --frozen-lockfile` + `sudo systemctl restart`
5. Health check (HTTP URL or systemd status fallback)
6. Auto-rollback on failure (restores DB snapshot + reverts to previous commit)

Per-app workflow. Copy and change the `with:` values:

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

## Adding a new service

1. Create a module in `modules/nixos/services/` using [mkService](./mkservice.md) or a custom module
2. Register secrets in `secrets/secrets.nix` and encrypt with agenix
3. Enable in the target machine's `default.nix`
4. Add a deploy workflow to the app repo (if it has one)

See `modules/nixos/services/cachet.nix` for a minimal mkService example.
