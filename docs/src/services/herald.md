# herald

Git SSH hosting with email notifications. Provides a git push interface over SSH and sends email via SMTP/DKIM.

**Domain:** `herald.dunkirk.sh` · **SSH Port:** 2223 · **HTTP Port:** 8085

This is a **custom module** — it does not use mkService.

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Enable herald |
| `domain` | string | — | Domain for Caddy reverse proxy |
| `host` | string | `"0.0.0.0"` | Listen address |
| `sshPort` | port | `2223` | SSH listen port |
| `externalSshPort` | port | `2223` | External SSH port (if behind NAT) |
| `httpPort` | port | `8085` | HTTP API port |
| `dataDir` | path | `"/var/lib/herald"` | Data directory |
| `allowAllKeys` | bool | `true` | Allow all SSH keys |
| `secretsFile` | path | — | Agenix secrets (must contain `SMTP_PASS`) |
| `package` | package | `pkgs.herald` | Herald package |

### SMTP

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `smtp.host` | string | — | SMTP server hostname |
| `smtp.port` | port | `587` | SMTP server port |
| `smtp.user` | string | — | SMTP username |
| `smtp.from` | string | — | Sender address |

### DKIM

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `smtp.dkim.selector` | string or null | `null` | DKIM selector |
| `smtp.dkim.domain` | string or null | `null` | DKIM signing domain |
| `smtp.dkim.privateKeyFile` | path or null | `null` | Path to DKIM private key |
