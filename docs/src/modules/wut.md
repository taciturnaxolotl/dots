# wut

**W**orktrees **U**nexpectedly **T**olerable — a git worktree manager that keeps worktrees organized under `.worktrees/`.

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `atelier.shell.wut.enable` | bool | `false` | Install wut and the zsh shell wrapper |

## Usage

```bash
wut new feat/my-feature   # Create worktree + branch under .worktrees/
wut list                   # Show all worktrees
wut go feat/my-feature     # cd into worktree (via shell wrapper)
wut go                     # Interactive picker
wut path feat/my-feature   # Print worktree path
wut rm feat/my-feature     # Remove worktree + delete branch
```

## Shell integration

Wut needs to `cd` the calling shell, which a subprocess can't do directly. It works by printing a `__WUT_CD__=/path` marker that a zsh wrapper function intercepts:

```zsh
wut() {
  output=$(/path/to/wut "$@")
  if [[ "$output" == *"__WUT_CD__="* ]]; then
    cd "${output##*__WUT_CD__=}"
  else
    echo "$output"
  fi
}
```

This wrapper is automatically injected into `initContent` when the module is enabled.

## Safety

- `wut rm` refuses to delete worktrees with uncommitted changes (use `--force` to override)
- `wut rm` warns before deleting unmerged branches
- The main/master branch worktree cannot be removed
