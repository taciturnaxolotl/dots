# AGENTS.md — dots

Kieran's NixOS/nix-darwin/home-manager dotfiles and homelab infrastructure.

## Machine Inventory

| Name | Type | Platform | Purpose |
|---|---|---|---|
| `atalanta` | nix-darwin | aarch64-darwin | Primary macOS workstation (Apple Silicon) |
| `terebithia` | NixOS | aarch64-linux | Main homelab server (ARM VPS, runs most services) |
| `prattle` | NixOS | x86_64-linux | Secondary server (deploys via deploy-rs) |
| `moonlark` | NixOS | x86_64-linux | VM (Disko-managed, /dev/vda) |
| `ember` | home-manager only | x86_64-linux | Standalone HM config |
| `nest` | home-manager only | x86_64-linux | Standalone HM config |
| `tacyon` | home-manager only | aarch64-linux | Standalone HM config |
| `iso-*` | NixOS ISO | x86_64 + aarch64 | Bootable install media |

## Apply Commands

```bash
# Darwin (atalanta — run locally on that machine)
darwin-rebuild switch --flake .#atalanta

# NixOS (run locally on target or via deploy-rs)
nixos-rebuild switch --flake .#terebithia
nixos-rebuild switch --flake .#prattle

# Standalone home-manager (run locally)
home-manager switch --flake .#tacyon

# Remote deploy via deploy-rs (from dev shell, uses Tailscale)
nix develop                                   # enters shell with deploy-rs
deploy .#terebithia
deploy .#prattle

# nh helper (preferred on NixOS hosts themselves)
nh os switch
nh home switch

# Format all Nix files
nix fmt

# Build ISO
nix build .#packages.x86_64-linux.iso
nix build .#packages.aarch64-linux.iso

# Build and serve docs
nix build .#packages.aarch64-darwin.docs
nix run .#packages.aarch64-darwin.docs.serve

# Inspect services manifest (JSON)
nix eval --json .#services-manifest
```

## Repo Layout

```
flake.nix              — single source of truth: all configurations, overlays, deploy nodes
machines/<name>/       — per-machine entry points (default.nix + home-manager.nix + home/)
modules/
  nixos/
    system/            — NixOS system modules (authentication, machine, wifi)
    services/          — service modules, mostly using mkService factory
    apps/              — NixOS-level app configs (tuigreet)
  home/
    system/            — home-manager system (shell, nixpkgs)
    aesthetics/        — theming (Catppuccin), wallpapers
    apps/              — home-manager app configs (helix, git, ghostty, etc.)
    wm/                — window manager configs (yabai/skhd, hyprland)
  shared/              — options shared across platforms (atelier.machine)
  lib/
    mkService.nix      — service factory (see below)
lib/
  services.nix         — utilities for extracting service metadata
  services-manifest.nix — generates the JSON manifest consumed by the docs/infra dashboard
secrets/
  secrets.nix          — agenix public key declarations
  *.age                — encrypted secrets
packages/              — custom derivations (bore-auth, curl-doom, docs, zmx)
dots/                  — raw config files (hyprland, yabai/skhd, wallpapers, scripts)
docs/                  — mdBook source; built by nix build .#packages.*.docs
```

## The `atelier` Namespace

All custom options live under `atelier.*`. This is the house namespace — not upstream NixOS options.

**Machine metadata** (`modules/shared/machine.nix`):
```nix
atelier.machine = {
  enable = true;
  type = "server";        # or "client"
  tailscaleHost = "hostname";
};
```
Setting `enable = true` makes the machine visible in the services manifest/dashboard.

**Services** (`modules/lib/mkService.nix`):
```nix
atelier.services.<name> = {
  enable = true;
  domain = "app.dunkirk.sh";
  port = 3000;
  secretsFile = config.age.secrets.<name>.path;
  repository = "https://github.com/...";   # cloned once on first start
  data.sqlite = "/var/lib/<name>/data/app.db";  # triggers WAL checkpoint + stop on backup
  data.files = [ "/var/lib/<name>/uploads" ];
};
```

The factory auto-creates: systemd service, dedicated user/group, `/var/lib/<name>/{app,data}` dirs, Caddy virtualHost with Cloudflare DNS TLS, port-conflict assertion, sudo rules so the service user can restart itself (for CI deploys), and restic backup integration.

Services that don't fit the factory pattern (herald, bore/frps, tangled knot/spindle, n8n, minio) are handled as custom service modules with manual wiring, but they still appear in the manifest via hardcoded entries in `lib/services.nix`.

## Adding a New Service

1. Create `modules/nixos/services/<name>.nix` — either use `mkService` or write a custom module.
2. Register the secret in `secrets/secrets.nix` (add the `.age` entry with `kierank` pubkey).
3. Create the encrypted secret: `agenix -e secrets/<name>.age` (must be run from `secrets/`).
4. In the target machine's `default.nix`, add:
   - `age.secrets.<name> = { file = ../../secrets/<name>.age; owner = "<name>"; };`
   - `atelier.services.<name>.enable = true;` and remaining options
5. Import the module (or rely on `import-tree` if it auto-discovers from `modules/nixos/`).
6. If Caddy is the proxy: the factory handles TLS automatically using Cloudflare DNS. Caddy needs `EnvironmentFile` pointing to the cloudflare secret (already wired in terebithia's `default.nix`).

## Secrets Management

- **Tool**: agenix (`agenix -e secrets/<name>.age`)
- **Identity**: `/Users/kierank/.ssh/id_rsa` (Darwin) or `/home/kierank/.ssh/id_rsa` + `/etc/ssh/id_rsa` (NixOS)
- **All secrets** encrypted to the single `kierank` RSA key in `secrets/secrets.nix`
- Secret files are referenced as `config.age.secrets.<name>.path` — this is a runtime path, not a store path; only available after activation

## Module Import Patterns

Two patterns in use — know which machine uses which:

**`import-tree`** (terebithia, atalanta): Automatically imports all `.nix` files under a directory tree. Used as `inputs.import-tree ../../modules/nixos` or `inputs.import-tree ../../../modules/home`. Any `.nix` file dropped in those trees is automatically included — no manual import list needed.

**Explicit imports** (moonlark, prattle): Individual `imports = [ ... ]` lists. Adding a module requires editing the machine's `default.nix`.

The home config for atalanta (`machines/atalanta/home/default.nix`) uses `import-tree` for `modules/home`, meaning all home modules are always available — they just won't activate without `atelier.<module>.enable = true`.

## Overlays and Custom Packages

A single `unstable-overlays` attrset is defined at the top of `flake.nix` and threaded into every configuration. It:
- Adds `pkgs.unstable` (nixpkgs-unstable) — access unstable packages via `pkgs.unstable.<name>`
- Adds `pkgs.zmx-binary`, `pkgs.bore-auth`, `pkgs.curl-doom`, `pkgs.pear`, `pkgs.herald`, `pkgs.tangle-of-trust`
- Overrides `bambu-studio` to a pinned version
- Darwin-only: disables `direnv` test suite (sandbox SIGKILL issue on macOS with libarchive >= 3.8.5)

The Darwin machine (`atalanta`) also defines its overlays inline in `default.nix` rather than relying solely on the flake-level ones, because nix-darwin handles `nixpkgs.overlays` differently.

## Formatting

`nix fmt` runs `nixfmt-tree` (RFC-style formatter). This is the formatter; don't use `nixfmt-rfc-style` manually on individual files when the tree formatter is available. The formatter is set per-system in `flake.nix`:
```nix
formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt-tree;
formatter.aarch64-darwin = nixpkgs.legacyPackages.aarch64-darwin.nixfmt-tree;
```

## CI/CD

**Servers (terebithia, prattle)**: `.github/workflows/deploy.yaml` — triggers on push to `main`. Uses deploy-rs with `--remote-build` over Tailscale. Captures pre-deploy generations, deploys in parallel matrix, auto-rolls back on failure. Docs build/publish follows a successful deploy.

**Application services**: `.github/workflows/deploy-service.yml` — SSH over Tailscale to service user, git pull, `bun install`, `sudo systemctl restart <name>`. Service users can restart their own service (sudoers rule from mkService).

**ISOs**: `.github/workflows/build-iso.yml`.

The deploy workflow uses `tag:deploy` Tailscale tags. CI needs `TS_OAUTH_CLIENT_ID` and `TS_OAUTH_SECRET` repo secrets.

## Theming

Global theme is **Catppuccin Macchiato** with green accent. The `atelier.theming.enable` option (from `modules/home/aesthetics/theming.nix`) wires catppuccin-nix across GTK, Qt (kvantum), qutebrowser, and cursor. The flavor and accent are hardcoded in that module — change there, not per-app.

## Nix Version Note

Both servers use **Lix** (`nix.package = pkgs.lixPackageSets.stable.lix`). Atalanta also uses Lix. This is a Nix fork; behavior is largely identical but error messages and some internals differ.

## Gotchas

- **`import-tree` is greedy**: every `.nix` file in `modules/nixos/` or `modules/home/` is evaluated on machines that use it. A syntax error anywhere in those trees breaks the whole configuration for those machines.
- **Port conflicts are asserted**: `mkService` checks for port collisions across all enabled services and will fail `nixos-rebuild` with a clear message. Check existing ports before picking a new one.
- **`ExecStartPre` with `!` prefix**: runs as root before namespace setup — intentional, to guarantee dirs exist before `WorkingDirectory` is validated by systemd. Don't remove the `!`.
- **agenix secrets are runtime paths**: `config.age.secrets.<name>.path` resolves to something like `/run/agenix/<name>`. It's not a store path. Don't try to use it at build time.
- **Caddy TLS**: all virtualHosts use Cloudflare DNS challenge (`dns cloudflare {env.CLOUDFLARE_API_TOKEN}`). The token comes from `age.secrets.cloudflare`, loaded via `systemd.services.caddy.serviceConfig.EnvironmentFile`. This is already wired in terebithia — new services just need their virtualHost configured.
- **deploy-rs `--remote-build`**: the build happens on the target machine, not in CI. This means CI just needs Nix + network, not build capacity. The dev shell (via `nix develop`) provides `deploy-rs`.
- **Darwin overlays duplication**: `atalanta/default.nix` re-declares `nixpkgs.overlays` inline instead of consuming `unstable-overlays`. This is because nix-darwin's `nixpkgs.overlays` option is separate from the module system's overlay injection. If you add a new overlay to `unstable-overlays` in `flake.nix`, also add it to `atalanta/default.nix` if atalanta needs it.
- **`services.nix` nixdoc format**: functions in `lib/services.nix` use nixdoc-compatible `/**` docstring syntax. Keep that format when adding functions there — it feeds the auto-generated docs.
