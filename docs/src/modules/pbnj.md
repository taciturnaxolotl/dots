# pbnj

Pastebin CLI with automatic language detection, clipboard integration, and agenix auth.

## Options

All options under `atelier.pbnj`:

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Install the pbnj CLI |
| `host` | string | — | Pastebin instance URL |
| `authKeyFile` | path | — | Path to auth key file (e.g. agenix secret) |

## Usage

```bash
pbnj                          # Interactive menu
pbnj upload myfile.py         # Upload file (auto-detects Python)
cat output.log | pbnj upload  # Upload from stdin
pbnj list                     # List pastes
pbnj delete <id>              # Delete a paste
```

Supports 25+ languages via file extension detection. Automatically copies the URL to clipboard (wl-copy/xclip/pbcopy depending on platform).
