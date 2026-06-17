# Modules

Custom NixOS and home-manager modules under the `atelier.*` namespace. These wrap and extend upstream packages with opinionated defaults and structured configuration.

All modules live under `modules/nixos/` and `modules/home/`. Machines using `import-tree` automatically discover every `.nix` file in those trees. Modules only activate when their `enable` option is set to `true`.

## Documented modules

These have detailed option references and examples:

### NixOS

- [tuigreet](./tuigreet.md) — login greeter (`atelier.apps.tuigreet`)
- [wifi](./wifi.md) — declarative Wi-Fi profiles with eduroam (`atelier.network.wifi`)

### Home-manager

- [shell](./shell.md) — zsh + oh-my-posh + Tangled tooling (`atelier.shell`)
- [ssh](./ssh.md) — SSH config with zmx persistent sessions (`atelier.ssh`)
- [helix](./helix.md) — evil-helix with LSPs, wakatime, harper (`atelier.apps.helix`)
- [bore (client)](./bore-client.md) — tunnel client CLI (`atelier.bore`)
- [pbnj](./pbnj.md) — pastebin CLI (`atelier.pbnj`)
- [wut](./wut.md) — git worktree manager (`atelier.shell.wut`)

## Other modules

Many more modules exist without dedicated doc pages. Browse the source:

- `modules/home/apps/` — ghostty, alacritty, git, jj, qutebrowser, spotify, halloy, irssi, tofi
- `modules/home/aesthetics/` — theming (Catppuccin), wallpapers
- `modules/home/wm/` — hyprland, yabai/skhd
- `modules/nixos/system/` — authentication, machine metadata
- `modules/nixos/services/` — 20+ service modules (see [Services](../services/README.md))
