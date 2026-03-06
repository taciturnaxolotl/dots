# ssh

Declarative SSH config with per-host options and zmx (persistent tmux-like sessions over SSH) integration.

## Options

All options under `atelier.ssh`:

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Enable SSH config management |
| `extraConfig` | string | `""` | Raw SSH config appended to the end |

### zmx

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `zmx.enable` | bool | `false` | Install zmx and autossh |
| `zmx.hosts` | list of strings | `[]` | Host patterns to auto-attach via zmx |

When zmx is enabled for a host, the SSH config injects `RemoteCommand`, `RequestTTY force`, and `ControlMaster`/`ControlPersist` settings. Shell aliases are also added: `zmls`, `zmk`, `zma`, `ash`.

### Hosts

Per-host config under `atelier.ssh.hosts.<name>`:

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `hostname` | string | — | SSH hostname or IP |
| `port` | int or null | `null` | SSH port |
| `user` | string or null | `null` | SSH user |
| `identityFile` | string or null | `null` | Path to SSH key |
| `forwardAgent` | bool | `false` | Forward SSH agent |
| `zmx` | bool | `false` | Enable zmx for this host |
| `extraOptions` | attrsOf string | `{}` | Arbitrary SSH options |

## Example

```nix
atelier.ssh = {
  enable = true;
  zmx.enable = true;
  zmx.hosts = [ "terebithia" "ember" ];

  hosts = {
    terebithia = {
      hostname = "terebithia";
      user = "kierank";
      forwardAgent = true;
      zmx = true;
    };
    "github.com" = {
      identityFile = "~/.ssh/id_rsa";
    };
  };
};
```
