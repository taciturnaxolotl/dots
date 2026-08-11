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
| `zmx.bypassEnv` | list of strings | `[ "ZMX_OFF" "AI_AGENT" "CLAUDECODE" "CRUSH" ]` | Env vars that turn zmx auto-attach off |

When zmx is enabled for a host, the SSH config injects `RemoteCommand`, `RequestTTY force`, and `ControlMaster`/`ControlPersist` settings. Shell aliases are also added: `zmls`, `zmk`, `zma`, `ash`.

#### Bypass

`RemoteCommand` makes one-shot commands a hard error: `ssh terebithia ls`, `scp`,
`rsync` and `git` over a zmx host all die with `Cannot execute command-line and
remote command`. To fix that, a `Match` block is emitted ahead of every host
block that cancels `RemoteCommand` when any variable in `zmx.bypassEnv` is set:

```
Match originalhost t.*,prattle,terebithia exec "test -n \"$ZMX_OFF$AI_AGENT$CLAUDECODE$CRUSH\""
  RemoteCommand none
  RequestTTY auto
```

So coding agents get plain SSH for free, and anyone else can opt out per command:

```bash
ZMX_OFF=1 ssh terebithia uptime
ZMX_OFF=1 rsync -a ./build/ terebithia:/srv/app/
```

Persistence is still available on purpose, without a TTY:

```bash
ssh terebithia zmx run build nix build .#foo   # runs in a session, survives disconnect
ssh terebithia zmx history build               # read the scrollback later
```

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
