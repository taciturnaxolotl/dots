# battleship-arena

Battleship game server with web interface and SSH-based bot submission.

**Domain:** `battleship.dunkirk.sh` · **Web Port:** 8081 · **SSH Port:** 2222

This is a **custom module** — it does not use mkService.

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Enable battleship-arena |
| `domain` | string | `"battleship.dunkirk.sh"` | Domain for Caddy reverse proxy |
| `sshPort` | port | `2222` | SSH port for bot submissions |
| `webPort` | port | `8081` | Web interface port |
| `uploadDir` | string | `"/var/lib/battleship-arena/submissions"` | Bot upload directory |
| `resultsDb` | string | `"/var/lib/battleship-arena/results.db"` | SQLite results database path |
| `adminPasscode` | string | `"battleship-admin-override"` | Admin passcode |
| `secretsFile` | path or null | `null` | Agenix secrets file |
| `package` | package | — | Battleship-arena package (from flake input) |
