# helix

Evil-helix (vim-mode fork) with comprehensive LSP setup, wakatime tracking on every language, and harper grammar checking.

## Options

All options under `atelier.apps.helix`:

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Enable helix configuration |
| `swift` | bool | `false` | Add sourcekit-lsp for Swift (platform-conditional) |

## Language servers

The module configures 15+ language servers out of the box:

| Language | Server |
|----------|--------|
| Nix | nixd + nil |
| TypeScript/JavaScript | typescript-language-server + biome |
| Go | gopls |
| Python | pylsp |
| Rust | rust-analyzer |
| HTML/CSS | vscode-html-language-server, vscode-css-language-server |
| JSON | vscode-json-language-server + biome |
| TOML | taplo |
| Markdown | marksman |
| YAML | yaml-language-server |
| Swift | sourcekit-lsp (when `swift = true`) |

All languages also get:
- **wakatime-ls** — coding time tracking
- **harper-ls** — grammar and spell checking

> **Note:** After install, run `hx -g fetch && hx -g build` to compile tree-sitter grammars.
