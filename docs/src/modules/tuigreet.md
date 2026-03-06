# tuigreet

Configures greetd with tuigreet as the login greeter. Exposes nearly every tuigreet CLI flag as a typed Nix option.

## Options

All options under `atelier.apps.tuigreet`:

### Core

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Enable tuigreet |
| `command` | string | `"Hyprland"` | Session command to run after login |
| `greeting` | string | *(unauthorized access warning)* | Greeting message |

### Display

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `time` | bool | `false` | Show clock |
| `timeFormat` | string | `"%H:%M"` | Clock format |
| `issue` | bool | `false` | Show `/etc/issue` |
| `width` | int | `80` | UI width |
| `theme` | string | `""` | Theme string |
| `asterisks` | bool | `false` | Show asterisks for password |
| `asterisksChar` | string | `"*"` | Character for password masking |

### Layout

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `windowPadding` | int | `0` | Window padding |
| `containerPadding` | int | `1` | Container padding |
| `promptPadding` | int | `1` | Prompt padding |
| `greetAlign` | enum | `"center"` | Greeting alignment: `left`, `center`, `right` |

### Session management

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `remember` | bool | `false` | Remember last username |
| `rememberSession` | bool | `false` | Remember last session |
| `rememberUserSession` | bool | `false` | Per-user session memory |
| `sessions` | string | `""` | Wayland session search path |
| `xsessions` | string | `""` | X11 session search path |
| `sessionWrapper` | string | `""` | Session wrapper command |

### User menu

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `userMenu` | bool | `false` | Show user selection menu |
| `userMenuMinUid` | int | `1000` | Minimum UID in user menu |
| `userMenuMaxUid` | int | `65534` | Maximum UID in user menu |

### Power commands

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `powerShutdown` | string | `""` | Shutdown command |
| `powerReboot` | string | `""` | Reboot command |

### Keybindings

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `kbCommand` | enum | `"F2"` | Key to switch command |
| `kbSessions` | enum | `"F3"` | Key to switch session |
| `kbPower` | enum | `"F12"` | Key for power menu |
