"""Mirror a knot's repos to GitHub.

`knot-sync hook` is the knot's post-receive hook: it passes a push on and tells the pusher how it went.
`knot-sync sweep` fast-forwards every repo, for anything no push reached (fork imports, a failed hook).

GitHub also gets its own commits (dependabot, release bots, merged PRs), so only fast-forwards
happen by default; a force-push or delete is passed on leased on the SHA the knot replaced.
"""

import json
import logging
import os
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass, field

KNOT_URL = os.environ["KNOT_URL"].rstrip("/")
OWNER_DID = os.environ["OWNER_DID"]
GITHUB_USERNAME = os.environ["GITHUB_USERNAME"]
GITHUB_URL = os.environ.get("GITHUB_URL", "https://github.com/{user}/{name}.git")
EXCLUDE = set(filter(None, os.environ.get("EXCLUDE", "").split(",")))
FETCH_REFSPECS = ["+refs/heads/*:refs/heads/*", "+refs/tags/*:refs/tags/*"]
FF_REFSPECS = ["refs/heads/*:refs/heads/*", "refs/tags/*:refs/tags/*"]
# Reads the token from the environment so it never lands in argv or on disk.
CREDENTIAL_HELPER = "!f() { echo username=$GITHUB_USERNAME; echo password=$GITHUB_TOKEN; }; f"
DIM, GREEN, YELLOW, RED, RESET = "\033[2m", "\033[32m", "\033[33m", "\033[31m", "\033[0m"

log = logging.getLogger("knot-sync")


@dataclass(frozen=True)
class Edit:
    ref: str
    old: str | None
    new: str | None


@dataclass(frozen=True)
class Ref:
    flag: str
    name: str
    summary: str


@dataclass
class Pushed:
    refs: list[Ref] = field(default_factory=list)
    remarks: list[str] = field(default_factory=list)

    def __iadd__(self, other):
        self.refs += other.refs
        self.remarks += other.remarks
        return self


class PushError(Exception):
    def __init__(self, stderr):
        super().__init__(stderr)
        self.lines = remote_lines(stderr) or [line for line in stderr.splitlines() if line.strip()]


def knot_xrpc(method, **params):
    query = urllib.parse.urlencode({k: v for k, v in params.items() if v})
    with urllib.request.urlopen(f"{KNOT_URL}/xrpc/{method}?{query}", timeout=30) as response:
        return json.load(response)


def hosted_repos():
    cursor = None
    while True:
        page = knot_xrpc("com.atproto.sync.listRepos", limit=500, cursor=cursor)
        yield from (repo["did"] for repo in page["repos"])
        cursor = page.get("cursor")
        if not cursor or not page["repos"]:
            return


def mirrored_name(did):
    """The GitHub repo name for a knot repo, or None if it isn't ours to mirror."""
    try:
        record = knot_xrpc(
            "com.atproto.repo.getRecord",
            repo=did, collection="org.tangled.repo.manifest", rkey="self",
        )
    except urllib.error.HTTPError:
        return None
    declaration = record["value"]["declaration"]
    if declaration["owner"] != OWNER_DID or declaration["name"] in EXCLUDE:
        return None
    return declaration["name"]


def git(*args, cwd=None, check=True):
    result = subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True)
    if check and result.returncode != 0:
        raise RuntimeError(f"git {args[0]} failed: {result.stderr.strip()[-2000:]}")
    return result


def remote_lines(stderr):
    return [text for line in stderr.splitlines() if line.startswith("remote:") and (text := line[7:].strip())]


def push(path, name, *refspecs, lease=None):
    lease_args = [f"--force-with-lease={lease}"] if lease else []
    url = GITHUB_URL.format(user=GITHUB_USERNAME, name=name)
    result = git(
        "-c", f"credential.helper={CREDENTIAL_HELPER}", "push", "--porcelain",
        *lease_args, url, *refspecs, cwd=path, check=False,
    )
    # Rejected refs still exit non-zero; only a push reporting no refs failed.
    lines = [line.split("\t") for line in result.stdout.splitlines() if line.count("\t") >= 2]
    if result.returncode != 0 and not lines:
        raise PushError(result.stderr)
    refs = [Ref(flag, spec.split(":", 1)[-1], summary) for flag, spec, summary in lines]
    # GitHub's remarks are progress noise unless it refused something.
    rejected = any(ref.flag == "!" for ref in refs)
    pushed = Pushed(refs, remote_lines(result.stderr) if rejected else [])
    for ref in pushed.refs:
        if ref.flag == "!":
            log.warning("%s: left %s alone on GitHub (%s)", name, ref.name, ref.summary)
        elif ref.flag != "=":
            log.info("%s: %s %s", name, ref.name, ref.summary)
    for remark in pushed.remarks:
        log.warning("%s: github: %s", name, remark)
    return pushed


def rewrites(path, edits):
    """The edits a fast-forward can't carry: deletes and force-pushes."""
    for edit in edits:
        if edit.old is None:
            continue
        if edit.new is None or git("merge-base", "--is-ancestor", edit.old, edit.new, cwd=path, check=False).returncode != 0:
            yield edit


def sync(path, name, edits):
    pushed = Pushed()
    for edit in rewrites(path, edits):
        spec = f"+{edit.ref}:{edit.ref}" if edit.new else f":{edit.ref}"
        pushed += push(path, name, spec, lease=f"{edit.ref}:{edit.old}")
    pushed += push(path, name, *FF_REFSPECS)
    return pushed


def parse_edits(lines):
    """git's `<old> <new> <ref>` hook lines, with all-zero ids as None."""
    edits = []
    for line in lines:
        parts = line.split()
        if len(parts) == 3:
            old, new, ref = (part if part.strip("0") else None for part in parts)
            edits.append(Edit(ref, old, new))
    return edits


def short(ref):
    if ref.startswith("refs/tags/"):
        return "tag " + ref.removeprefix("refs/tags/")
    return ref.removeprefix("refs/heads/")


def render(where, pushed):
    yield f"{DIM}mirrored to {where}{RESET}"
    for ref in pushed.refs:
        if ref.flag == "!":
            yield f"  {YELLOW}{short(ref.name)}{RESET} {DIM}left alone on GitHub ({ref.summary}){RESET}"
        elif ref.flag != "=":
            color = RED if ref.flag == "-" else GREEN
            yield f"  {color}{short(ref.name)}{RESET} {DIM}{ref.summary.split(' (')[0]}{RESET}"
    for remark in pushed.remarks[:8]:
        yield f"  {DIM}{remark}{RESET}"


def render_failure(where, error):
    yield f"{RED}mirror to {where} failed{RESET}"
    for line in error.lines[-5:]:
        yield f"  {DIM}{line}{RESET}"


def hook():
    """Stdout goes back to the pusher; logging goes to stderr, which the knot logs."""
    edits = parse_edits(sys.stdin.read().splitlines())
    name = mirrored_name(os.environ["KNOT_REPO_DID"])
    if name is None or not edits:
        return
    where = f"github.com/{GITHUB_USERNAME}/{name}"
    try:
        lines = render(where, sync(os.environ["GIT_DIR"], name, edits))
    except PushError as error:
        lines = render_failure(where, error)
    print("\n".join(lines))


def sweep():
    mirrors = os.path.join(os.environ["STATE_DIRECTORY"], "mirrors")
    for did in hosted_repos():
        name = mirrored_name(did)
        if name is None:
            continue
        path = os.path.join(mirrors, f"{did}.git")
        try:
            if os.path.isdir(path):
                git("fetch", "--quiet", "--prune", "origin", *FETCH_REFSPECS, cwd=path)
            else:
                git("clone", "--quiet", "--mirror", f"{KNOT_URL}/{did}", path)
            push(path, name, *FF_REFSPECS)
        except (PushError, RuntimeError) as error:
            log.error("mirror %s failed: %s", name, error)


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, format="%(message)s", stream=sys.stderr)
    {"hook": hook, "sweep": sweep}[sys.argv[1]]()
