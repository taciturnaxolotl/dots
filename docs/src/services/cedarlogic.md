# cedarlogic

Browser-based circuit simulator with real-time collaboration via WebSockets.

**Domain:** `cedarlogic.dunkirk.sh` · **Port:** 3100 · **Runtime:** custom

## Extra options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `wsPort` | port | `3101` | Hocuspocus WebSocket server for document collaboration |
| `cursorPort` | port | `3102` | Cursor relay WebSocket server for live cursors |
| `branch` | string | `"web"` | Git branch to clone (uses `web` branch, not `main`) |

## Caddy routing

Cedarlogic disables the default mkService Caddy config and uses path-based routing to three backends:

| Path | Backend |
|------|---------|
| `/ws` | `wsPort` (Hocuspocus) |
| `/cursor-ws` | `cursorPort` (cursor relay) |
| `/api/*`, `/auth/*` | main `port` |
| Everything else | Static files from `dist/` |

## Build step

On initial scaffold, cedarlogic installs deps and builds:

```
bun install → parse-gates → bun run build (Vite)
```

Subsequent deploys handle their own build via the deploy workflow. The build has a 120s timeout to accommodate Vite compilation.
