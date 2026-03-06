# shell

Zsh configuration with oh-my-posh prompt, syntax highlighting, fzf-tab, zoxide, and Tangled git workflow tooling.

## Options

All options under `atelier.shell`:

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Enable shell configuration |

### Tangled

Options for the `tangled-setup` and `mkdev` scripts that manage dual-remote git workflows (Tangled knot + GitHub).

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `tangled.plcId` | string | — | ATProto DID for Tangled identity |
| `tangled.githubUser` | string | — | GitHub username |
| `tangled.knotHost` | string | — | Knot git host (e.g. `knot.dunkirk.sh`) |
| `tangled.domain` | string | — | Tangled domain for repo URLs |
| `tangled.defaultBranch` | string | `"main"` | Default branch name |

### Included tools

- **`tangled-setup`** — configures a repo with `origin` pointing to knot and `github` pointing to GitHub
- **`mkdev`** — creates a new repo on both Tangled and GitHub simultaneously
- **oh-my-posh** — custom prompt showing path, git status (ahead/behind), exec time, nix-shell indicator, ZMX session, SSH hostname
- **Aliases** — `cat=bat`, `ls=eza`, `cd=z` (zoxide), and more
