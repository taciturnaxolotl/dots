# Installation

> **Warning:** This configuration will not work without changing the [secrets](https://github.com/taciturnaxolotl/dots/tree/main/secrets) since they are encrypted with agenix.

## macOS with nix-darwin

1. Install Nix:

```bash
curl -fsSL https://install.determinate.systems/nix | sh -s -- install
```

2. Clone and apply:

```bash
git clone git@github.com:taciturnaxolotl/dots.git
cd dots
darwin-rebuild switch --flake .#atalanta
```

## Home Manager

Install Nix, copy SSH keys, then:

```bash
curl -fsSL https://install.determinate.systems/nix | sh -s -- install --determinate
git clone git@github.com:taciturnaxolotl/dots.git
cd dots
nix-shell -p home-manager
home-manager switch --flake .#nest
```

Set up [atuin](https://atuin.sh/) for shell history sync:

```bash
atuin login
atuin import
```

## NixOS

### Using nixos-anywhere (recommended for remote)

> Only works with `prattle` and `terebithia` which have disko configs.

```bash
nix run github:nix-community/nixos-anywhere -- \
  --flake .#prattle \
  --generate-hardware-config nixos-facter ./machines/prattle/facter.json \
  --build-on-remote \
  root@<ip-address>
```

### Using the install script

```bash
curl -L https://raw.githubusercontent.com/taciturnaxolotl/dots/main/install.sh -o install.sh
chmod +x install.sh
./install.sh
```

### Post-install

After first boot, log in with user `kierank` and the default password, then:

```bash
passwd kierank
sudo mv /etc/nixos ~/dots
sudo ln -s ~/dots /etc/nixos
sudo chown -R $(id -un):users ~/dots
atuin login && atuin sync
```
