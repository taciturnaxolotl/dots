# Modules

Custom NixOS and home-manager modules under the `atelier.*` namespace. These wrap and extend upstream packages with opinionated defaults and structured configuration.

## NixOS modules

| Module | Namespace | Description |
|--------|-----------|-------------|
| [tuigreet](./tuigreet.md) | `atelier.apps.tuigreet` | Login greeter with 30+ typed options |
| [wifi](./wifi.md) | `atelier.network.wifi` | Declarative Wi-Fi profiles with eduroam support |
| authentication | `atelier.authentication` | Fingerprint + PAM stack (fprintd, polkit, gnome-keyring) |

## Home-manager modules

| Module | Namespace | Description |
|--------|-----------|-------------|
| [shell](./shell.md) | `atelier.shell` | Zsh + oh-my-posh + Tangled workflow tooling |
| [ssh](./ssh.md) | `atelier.ssh` | SSH config with zmx persistent sessions |
| [helix](./helix.md) | `atelier.apps.helix` | Evil-helix with 15+ LSPs, wakatime, harper |
| [bore (client)](./bore-client.md) | `atelier.bore` | Tunnel client CLI for the bore server |
| [pbnj](./pbnj.md) | `atelier.pbnj` | Pastebin CLI with language detection |
| [wut](./wut.md) | `atelier.shell.wut` | Git worktree manager |
