# bore (client)

Interactive CLI for creating tunnels to the [bore server](../services/bore.md). Built with gum, supports HTTP, TCP, and UDP tunnels.

## Options

All options under `atelier.bore`:

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Install the bore CLI |
| `serverAddr` | string | `"bore.dunkirk.sh"` | frps server address |
| `serverPort` | port | `7000` | frps server port |
| `domain` | string | `"bore.dunkirk.sh"` | Base domain for constructing public URLs |
| `authTokenFile` | path | — | Path to frp auth token file |

## Usage

```bash
bore                  # Interactive menu
bore myapp 3000       # Quick HTTP tunnel: myapp.bore.dunkirk.sh → localhost:3000
bore myapp 3000 --auth  # With OAuth authentication
bore myapp 3000 --save  # Save to bore.toml for reuse
```

Tunnels can also be defined in a `bore.toml`:

```toml
[myapp]
port = 3000
auth = true
labels = ["dev"]
```
