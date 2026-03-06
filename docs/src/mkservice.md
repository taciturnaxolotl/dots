# mkService

`modules/lib/mkService.nix` is the service factory used by most atelier services. It takes a set of parameters and returns a NixOS module with standardized options, systemd service, Caddy reverse proxy, and backup integration.

## Factory parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `name` | string | *required* | Service identity — used for user, group, systemd unit, and option namespace |
| `description` | string | `"<name> service"` | Human-readable description |
| `defaultPort` | int | `3000` | Default port if not overridden in config |
| `runtime` | string | `"bun"` | `"bun"`, `"node"`, or `"custom"` |
| `entryPoint` | string | `"src/index.ts"` | Script to run (ignored if `startCommand` is set) |
| `startCommand` | string | `null` | Override the full start command |
| `extraOptions` | attrset | `{}` | Additional NixOS options for this service |
| `extraConfig` | function | `cfg: {}` | Additional NixOS config when enabled (receives the service config) |

## Options

Every mkService module creates options under `atelier.services.<name>`:

### Core

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Enable the service |
| `domain` | string | *required* | Domain for Caddy reverse proxy |
| `port` | port | `defaultPort` | Port the service listens on |
| `dataDir` | path | `"/var/lib/<name>"` | Data storage directory |
| `secretsFile` | path or null | `null` | Agenix secrets environment file |
| `repository` | string or null | `null` | Git repo URL — cloned once on first start |
| `healthUrl` | string or null | `null` | Health check URL for monitoring |
| `environment` | attrset | `{}` | Additional environment variables |

### Data declarations

Used by the backup system to automatically discover what to back up.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `data.sqlite` | string or null | `null` | SQLite database path (WAL checkpoint + stop/start during backup) |
| `data.postgres` | string or null | `null` | PostgreSQL database name (pg_dump during backup) |
| `data.files` | list of strings | `[]` | Additional file paths to back up |
| `data.exclude` | list of strings | `["*.log", "node_modules", ...]` | Glob patterns to exclude |

### Caddy

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `caddy.enable` | bool | `true` | Enable Caddy reverse proxy |
| `caddy.extraConfig` | string | `""` | Additional Caddy directives |
| `caddy.rateLimit.enable` | bool | `false` | Enable rate limiting |
| `caddy.rateLimit.events` | int | `60` | Requests per window |
| `caddy.rateLimit.window` | string | `"1m"` | Rate limit time window |

## What it sets up

- **System user and group** — dedicated user in the `services` group with sudo for `systemctl restart/stop/start/status`
- **Systemd service** — `ExecStartPre` creates dirs as root, `preStart` clones repo and installs deps, `ExecStart` runs the application
- **Caddy virtual host** — TLS via Cloudflare DNS challenge, reverse proxy to localhost port
- **Port conflict detection** — assertions prevent two services from binding the same port
- **Security hardening** — `NoNewPrivileges`, `ProtectSystem=strict`, `ProtectHome`, `PrivateTmp`

## Example

Minimal service module:

```nix
let
  mkService = import ../../lib/mkService.nix;
in
mkService {
  name = "myapp";
  description = "My application";
  defaultPort = 3000;
  runtime = "bun";
  entryPoint = "src/index.ts";

  extraConfig = cfg: {
    systemd.services.myapp.serviceConfig.Environment = [
      "DATABASE_PATH=${cfg.dataDir}/data/app.db"
    ];

    atelier.services.myapp.data = {
      sqlite = "${cfg.dataDir}/data/app.db";
    };
  };
}
```

Then enable in the machine config:

```nix
atelier.services.myapp = {
  enable = true;
  domain = "myapp.dunkirk.sh";
  repository = "https://github.com/taciturnaxolotl/myapp";
  secretsFile = config.age.secrets.myapp.path;
  healthUrl = "https://myapp.dunkirk.sh/health";
};
```
