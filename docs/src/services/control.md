# control

Admin dashboard for Caddy feature toggles. Provides a web UI to enable/disable paths on other services (e.g. blocking player tracking on the map).

**Domain:** `control.dunkirk.sh` · **Port:** 3010 · **Runtime:** bun

## Extra options

### `flags`

Defines per-domain feature flags that control blocks paths and redacts JSON fields.

```nix
atelier.services.control.flags."map.dunkirk.sh" = {
  name = "Map";
  flags = {
    "block-tracking" = {
      name = "Block Player Tracking";
      description = "Disable real-time player location updates";
      paths = [
        "/sse"
        "/sse/*"
        "/tiles/*/markers/pl3xmap_players.json"
      ];
      redact."/tiles/settings.json" = [ "players" ];
    };
  };
};
```

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `flags` | attrsOf submodule | `{}` | Services and their feature flags, keyed by domain |
| `flags.<domain>.name` | string | — | Display name for the service |
| `flags.<domain>.flags.<id>.name` | string | — | Display name for the flag |
| `flags.<domain>.flags.<id>.description` | string | — | What the flag does |
| `flags.<domain>.flags.<id>.paths` | list of strings | `[]` | URL paths to block when flag is active |
| `flags.<domain>.flags.<id>.redact` | attrsOf (list of strings) | `{}` | JSON fields to redact from responses, keyed by path |

The flags config is serialized to `flags.json` and passed to control via the `FLAGS_CONFIG` environment variable.
