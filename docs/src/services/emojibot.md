# emojibot

Slack emoji management service. Supports multiple instances for different workspaces.

**Runtime:** bun · **Stateless** (no database)

This is a **custom module** — it does not use mkService. Each instance gets its own systemd service, user, and Caddy virtual host.

## Instance options

Instances are defined under `atelier.services.emojibot.instances.<name>`:

```nix
atelier.services.emojibot.instances = {
  hackclub = {
    enable = true;
    domain = "hc.emojibot.dunkirk.sh";
    port = 3002;
    workspace = "hackclub";
    channel = "C02T3CU03T3";
    repository = "https://github.com/taciturnaxolotl/emojibot";
    secretsFile = config.age.secrets."emojibot/hackclub".path;
    healthUrl = "https://hc.emojibot.dunkirk.sh/health";
  };
};
```

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Enable this instance |
| `domain` | string | — | Domain for Caddy reverse proxy |
| `port` | port | — | Port to run on |
| `secretsFile` | path | — | Agenix secrets file with Slack credentials |
| `repository` | string | `"https://github.com/taciturnaxolotl/emojibot"` | Git repo URL |
| `workspace` | string or null | `null` | Slack workspace name (for identification) |
| `channel` | string or null | `null` | Slack channel ID |
| `healthUrl` | string or null | `null` | Health check URL for monitoring |

## Current instances

| Instance | Domain | Port | Workspace |
|----------|--------|------|-----------|
| hackclub | hc.emojibot.dunkirk.sh | 3002 | Hack Club |
| df1317 | df.emojibot.dunkirk.sh | 3005 | df1317 |
