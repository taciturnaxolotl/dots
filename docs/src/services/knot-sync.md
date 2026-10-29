# knot-sync

Mirrors Tangled knot repositories to GitHub as a long-running service.

This is a **custom module**; it does not use mkService. Knot 2 runs no repo hooks, so instead of a post-receive hook it follows the knot's atproto firehose (`com.atproto.sync.subscribeRepos`) and mirrors a repo as soon as an `org.tangled.git.pushEvent` frame says a ref moved. A full sweep of every repo runs at startup and every `sweepInterval`, which catches anything missed while the stream was down.

It keeps its own bare mirrors in `/var/lib/knot-sync/mirrors`, fetched over the knot's HTTP listener, so it never writes into the knot's repositories. Each repo's name and owner come from its `org.tangled.repo.manifest` record on the knot, read at mirror time, so renames are followed automatically.

## GitHub-side work is never clobbered

GitHub is not a pure mirror: dependabot branches, release tags and merged PRs live there too.

- A sweep only **fast-forwards**. It never deletes and never forces; a ref that has diverged on GitHub is logged (`left refs/heads/main alone on GitHub`) and skipped.
- A **deletion or force-push** only propagates when a push event reports it, and only with `--force-with-lease` on the SHA the knot replaced, so it lands only if GitHub still holds exactly that.

A diverged ref needs reconciling by hand: pull the GitHub commits into the knot, then the next sweep fast-forwards.

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Enable knot-sync |
| `knotUrl` | string | `"http://127.0.0.1:5555"` | The knot's local HTTP listener |
| `ownerDid` | string | — | Only repos owned by this DID are mirrored |
| `githubUsername` | string | `"taciturnaxolotl"` | Mirrors go to `github.com/<user>/<repo name>` |
| `secretsFile` | path | — | Agenix env file containing `GITHUB_TOKEN` |
| `exclude` | list of string | `[ ]` | Repo names never to mirror |
| `sweepInterval` | int | `21600` | Seconds between full sweeps |

The GitHub repo must already exist; a missing one is logged and skipped.
