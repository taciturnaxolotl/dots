# Services

All services run behind Caddy with Cloudflare DNS TLS. Most use the [mkService](../mkservice.md) factory which provides systemd units, dedicated users, reverse proxy, backup integration, and port conflict detection.

## Live status

- **Dashboard:** [infra.dunkirk.sh](https://infra.dunkirk.sh)
- **Machine manifest:** `nix eval --json .#services-manifest` or [`/services.json`](../services.json)

## Service documentation

These services have detailed option references and architecture notes:

- [bore](./bore.md) — HTTP/TCP/UDP tunnel proxy with optional OAuth
- [cedarlogic](./cedarlogic.md) — circuit simulator with WebSocket collaboration
- [control](./control.md) — admin dashboard for Caddy feature toggles
- [emojibot](./emojibot.md) — multi-instance Slack emoji management
- [herald](./herald.md) — git SSH hosting with email via SMTP/DKIM
- [knot-sync](./knot-sync.md) — mirrors Tangled knot repos to GitHub on cron

For all other services, check the manifest or the module source in `modules/nixos/services/`.
