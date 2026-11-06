# knot-sync

Mirrors Tangled knot repositories to GitHub.

This is a **custom module**; it does not use mkService. Upstream knot 2 runs no repo hooks, so the knot here is patched (`patches/knot-post-receive-hook.patch`) to run the executable in `KNOT_POST_RECEIVE_HOOK` after every push and send its output back to the pusher.

## On push

`knot-sync hook` runs as the knot's post-receive hook. It pushes straight from the knot's repository and reports back as `remote:` lines:

```
remote: mirrored to github.com/taciturnaxolotl/dots
remote:   main 58f65e3..1a2b3c4
```

A ref GitHub refuses is shown in yellow with GitHub's reason, so secret-scanning blocks (GH013) are visible at push time. The knot kills the hook and everything it started after `hookTimeout` seconds; the push itself has landed either way.

## Sweep

A `knot-sync` timer fast-forwards every repo every `sweepInterval`, for ref changes that never arrive as a push (fork and import creation) or a hook that failed. It keeps its own bare mirrors in `/var/lib/knot-sync/mirrors`, fetched over the knot's HTTP listener, so it never writes into the knot's repositories.

Each repo's name and owner come from its `org.tangled.repo.manifest` record, read every time, so renames are followed automatically.

## GitHub-side work is never clobbered

GitHub is not a pure mirror: dependabot branches, release tags and merged PRs live there too.

- By default only **fast-forwards** are pushed. A ref that has diverged on GitHub is left alone and reported (`left alone on GitHub`).
- A **deletion or force-push** is passed on only by the hook, with `--force-with-lease` on the SHA the knot replaced, so it lands only if GitHub still holds exactly that.
- Branches deleted from the web UI (`deleteBranch`) are not a push, so they stay on GitHub.

A diverged ref needs reconciling by hand: pull the GitHub commits into the knot and push.

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Enable knot-sync |
| `knotUrl` | string | `"http://127.0.0.1:5555"` | The knot's local HTTP listener |
| `ownerDid` | string | — | Only repos owned by this DID are mirrored |
| `githubUsername` | string | `"taciturnaxolotl"` | Mirrors go to `github.com/<user>/<repo name>` |
| `secretsFile` | path | — | Agenix env file containing `GITHUB_TOKEN` |
| `exclude` | list of string | `[ ]` | Repo names never to mirror |
| `sweepInterval` | string | `"6h"` | systemd time span between sweeps |
| `hookTimeout` | int | `60` | Seconds the knot waits on the hook |

The hook runs as the knot's user, so `secretsFile` must be readable by the `knot` group (on terebithia the agenix secret is `group = "knot"; mode = "0440"`). The GitHub repo must already exist; a missing one is reported and skipped.
