# bore (server)

Lightweight tunneling server built on frp. Supports HTTP (wildcard subdomains), TCP, and UDP tunnels with optional OAuth authentication via Indiko.

**Domain:** `bore.dunkirk.sh` · **frp port:** 7000

This is a **custom module** — it does not use mkService.

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Enable bore server |
| `domain` | string | — | Base domain for wildcard subdomains |
| `bindAddr` | string | `"0.0.0.0"` | frps bind address |
| `bindPort` | port | `7000` | frps bind port |
| `vhostHTTPPort` | port | `7080` | Virtual host HTTP port |
| `allowedTCPPorts` | list of ports | `20000–20099` | Ports available for TCP tunnels |
| `allowedUDPPorts` | list of ports | `20000–20099` | Ports available for UDP tunnels |
| `authToken` | string or null | `null` | frp auth token (use `authTokenFile` instead) |
| `authTokenFile` | path or null | `null` | Path to file containing frp auth token |
| `enableCaddy` | bool | `true` | Auto-configure Caddy wildcard vhost |

### Authentication

When enabled, all HTTP tunnels are gated behind Indiko OAuth. Users must sign in before accessing tunneled services.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `auth.enable` | bool | `false` | Enable bore-auth OAuth middleware |
| `auth.indikoURL` | string | `"https://indiko.dunkirk.sh"` | Indiko server URL |
| `auth.clientID` | string | — | OAuth client ID from Indiko |
| `auth.clientSecretFile` | path | — | Path to OAuth client secret |
| `auth.cookieHashKeyFile` | path | — | 32-byte cookie signing key |
| `auth.cookieBlockKeyFile` | path | — | 32-byte cookie encryption key |

After authentication, these headers are passed to tunneled services:

- `X-Auth-User` — user's profile URL
- `X-Auth-Name` — display name
- `X-Auth-Email` — email address

See [bore (client)](../modules/bore-client.md) for the home-manager client module.
