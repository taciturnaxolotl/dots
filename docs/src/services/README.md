# Services

All services run on **terebithia** (Oracle Cloud aarch64) behind Caddy with Cloudflare DNS TLS.

## mkService-based

| Service | Domain | Port | Runtime | Description |
|---------|--------|------|---------|-------------|
| cachet | cachet.dunkirk.sh | 3000 | bun | Slack emoji/profile cache |
| hn-alerts | hn.dunkirk.sh | 3001 | bun | Hacker News monitoring |
| indiko | indiko.dunkirk.sh | 3003 | bun | IndieAuth/OAuth2 server |
| l4 | l4.dunkirk.sh | 3004 | bun | Image CDN — Slack image optimizer |
| canvas-mcp | canvas.dunkirk.sh | 3006 | bun | Canvas MCP server |
| control | control.dunkirk.sh | 3010 | bun | Admin dashboard for Caddy toggles |
| traverse | traverse.dunkirk.sh | 4173 | bun | Code walkthrough diagram server |
| cedarlogic | cedarlogic.dunkirk.sh | 3100 | custom | Circuit simulator |

## Multi-instance

| Service | Domain | Port | Description |
|---------|--------|------|-------------|
| emojibot-hackclub | hc.emojibot.dunkirk.sh | 3002 | Emojibot for Hack Club |
| emojibot-df1317 | df.emojibot.dunkirk.sh | 3005 | Emojibot for df1317 |

## Custom / external

| Service | Domain | Description |
|---------|--------|-------------|
| bore (frps) | bore.dunkirk.sh | HTTP/TCP/UDP tunnel proxy |
| herald | herald.dunkirk.sh | Git SSH hosting + email |
| knot | knot.dunkirk.sh | Tangled git hosting |
| spindle | spindle.dunkirk.sh | Tangled CI |
| battleship-arena | battleship.dunkirk.sh | Battleship game server |
| n8n | n8n.dunkirk.sh | Workflow automation |

## Architecture

Each mkService module provides:

- **Systemd service** — initial git clone for scaffolding, subsequent deploys via GitHub Actions
- **Caddy reverse proxy** — TLS via Cloudflare DNS challenge, optional rate limiting
- **Data declarations** — `sqlite`, `postgres`, `files` feed into automatic backups
- **Dedicated user** — sudo for restart/stop/start, per-user Tailscale SSH ACLs
- **Port conflict detection** — assertions prevent two services binding the same port
