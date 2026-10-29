"""Mirror a knot 2's repositories to GitHub.

Knot 2 runs no repo hooks, so instead of a post-receive hook this follows
the knot's own event stream and mirrors a repo whenever a ref moves. A full
sweep runs at startup and on an interval, so anything missed while the
stream was down (or a GitHub outage) catches up on its own.

GitHub is not a pure mirror: dependabot opens branches there, release
workflows cut tags there, and PRs get merged there. So nothing here is
allowed to clobber GitHub-side work:

- A sweep only fast-forwards. It never deletes and never forces, so a ref
  that has diverged on GitHub is reported and left alone.
- A deletion or a force-push only propagates when the knot's event stream
  says it happened, and only with a lease on the old SHA, so it lands only
  if GitHub still holds exactly what the knot replaced.

Mirrors live in our own state dir, fetched over the knot's HTTP listener,
so we never write into the knot's repositories.
"""

import asyncio
import json
import logging
import os
import subprocess
import time
import urllib.parse
import urllib.request

import websockets

KNOT_URL = os.environ["KNOT_URL"].rstrip("/")
KNOT_HOSTNAME = os.environ["KNOT_HOSTNAME"]
OWNER_DID = os.environ["OWNER_DID"]
PLC_URL = os.environ.get("PLC_URL", "https://plc.directory").rstrip("/")
GITHUB_USERNAME = os.environ["GITHUB_USERNAME"]
GITHUB_URL = os.environ.get(
    "GITHUB_URL", "https://github.com/{user}/{name}.git"
)
STATE_DIR = os.environ["STATE_DIR"]
EXCLUDE = {name for name in os.environ.get("EXCLUDE", "").split(",") if name}
SWEEP_SECS = int(os.environ.get("SWEEP_SECS", "21600"))
DEBOUNCE_SECS = 5
NAME_REFRESH_SECS = 60
# Both namespaces, since a repo record may sit in either mid-migration.
REPO_COLLECTIONS = ("org.tangled.repo", "sh.tangled.repo")
FETCH_REFSPECS = ["+refs/heads/*:refs/heads/*", "+refs/tags/*:refs/tags/*"]
# No leading `+`: GitHub refuses anything that isn't a fast-forward.
FF_REFSPECS = ["refs/heads/*:refs/heads/*", "refs/tags/*:refs/tags/*"]
# Reads GITHUB_TOKEN from the environment so it never lands in argv or a
# remote URL on disk.
CREDENTIAL_HELPER = (
    "!f() { echo username=$GITHUB_USERNAME; echo password=$GITHUB_TOKEN; }; f"
)

log = logging.getLogger("knot-sync")


def get_json(url):
    request = urllib.request.Request(url, headers={"User-Agent": "knot-sync"})
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)


class Names:
    """repo DID -> repo name, read from the owner's repo records."""

    def __init__(self):
        self.by_did = {}
        self.refreshed_at = 0.0

    def refresh(self):
        doc = get_json(f"{PLC_URL}/{OWNER_DID}")
        pds = next(
            service["serviceEndpoint"]
            for service in doc["service"]
            if service["id"] == "#atproto_pds"
        ).rstrip("/")
        found = {}
        for collection in REPO_COLLECTIONS:
            cursor = None
            while True:
                params = {
                    "repo": OWNER_DID,
                    "collection": collection,
                    "limit": "100",
                }
                if cursor:
                    params["cursor"] = cursor
                query = urllib.parse.urlencode(params)
                page = get_json(
                    f"{pds}/xrpc/com.atproto.repo.listRecords?{query}"
                )
                for record in page.get("records", []):
                    value = record["value"]
                    # Newer records drop `name` and let the rkey carry it.
                    rkey = record["uri"].rsplit("/", 1)[-1]
                    did, name = value.get("repoDid"), value.get("name") or rkey
                    if did and value.get("knot") == KNOT_HOSTNAME:
                        found.setdefault(did, name)
                cursor = page.get("cursor")
                if not cursor or not page.get("records"):
                    break
        self.by_did = found
        self.refreshed_at = time.monotonic()
        log.info("resolved %d repo names", len(found))

    def lookup(self, did):
        stale = time.monotonic() - self.refreshed_at > NAME_REFRESH_SECS
        if did not in self.by_did and stale:
            try:
                self.refresh()
            except Exception:
                log.exception("failed to refresh repo names")
        return self.by_did.get(did)


def git(*args, cwd=None, check=True):
    result = subprocess.run(
        ["git", *args], cwd=cwd, capture_output=True, text=True
    )
    if check and result.returncode != 0:
        raise RuntimeError(
            f"git {args[0]} failed: {result.stderr.strip()[-2000:]}"
        )
    return result


def push(path, name, *refspecs, lease=None):
    """Push to GitHub, returning git's porcelain lines that aren't up to date."""
    args = ["-c", f"credential.helper={CREDENTIAL_HELPER}", "push", "--porcelain"]
    if lease:
        args.append(f"--force-with-lease={lease}")
    args += [GITHUB_URL.format(user=GITHUB_USERNAME, name=name), *refspecs]
    # A rejected ref exits non-zero but still reports per-ref status, which
    # is what we want; only a push that reports nothing at all is an error.
    result = git(*args, cwd=path, check=False)
    lines = [
        line.split("\t")
        for line in result.stdout.splitlines()
        if line.count("\t") >= 2
    ]
    if result.returncode != 0 and not lines:
        raise RuntimeError(f"push failed: {result.stderr.strip()[-2000:]}")
    return [(flag, refs, summary) for flag, refs, summary in lines if flag != "="]


def report(name, results):
    for flag, refs, summary in results:
        ref = refs.split(":", 1)[-1]
        if flag == "!":
            log.warning("%s: left %s alone on GitHub (%s)", name, ref, summary)
        else:
            log.info("%s: %s %s", name, ref, summary)


def mirror(did, name, updates):
    path = os.path.join(STATE_DIR, "mirrors", f"{did}.git")
    if not os.path.isdir(path):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        git("clone", "--quiet", "--mirror", f"{KNOT_URL}/{did}", path)
    else:
        git("fetch", "--quiet", "--prune", "origin", *FETCH_REFSPECS, cwd=path)

    # Deletes and force-pushes the knot told us about, each leased on the
    # SHA the knot replaced. Plain fast-forwards fall through to the sweep
    # push below, so they don't need a lease.
    for ref, (old, new) in updates.items():
        deleted = set(new) == {"0"}
        created = set(old) == {"0"}
        if created:
            continue
        if not deleted:
            merge_base = git("merge-base", "--is-ancestor", old, new, cwd=path, check=False)
            if merge_base.returncode == 0:
                continue
        refspec = f":{ref}" if deleted else f"+{ref}:{ref}"
        report(name, push(path, name, refspec, lease=f"{ref}:{old}"))

    report(name, push(path, name, *FF_REFSPECS))


class Syncer:
    def __init__(self):
        self.names = Names()
        # did -> (due time, {ref: (oldest old sha, newest new sha)})
        self.pending = {}
        self.wake = asyncio.Event()

    def schedule(self, did, delay=DEBOUNCE_SECS, ref=None, old=None, new=None):
        due = time.monotonic() + delay
        at, updates = self.pending.get(did, (due, {}))
        if ref:
            first_old = updates[ref][0] if ref in updates else old
            updates[ref] = (first_old, new)
        self.pending[did] = (min(at, due), updates)
        self.wake.set()

    async def sweep(self):
        try:
            await asyncio.to_thread(self.names.refresh)
        except Exception:
            log.exception("sweep: failed to resolve repo names")
            return
        for did in self.names.by_did:
            self.schedule(did, delay=0)

    async def sweeper(self):
        while True:
            await self.sweep()
            await asyncio.sleep(SWEEP_SECS)

    async def worker(self):
        while True:
            now = time.monotonic()
            due = [did for did, (at, _) in self.pending.items() if at <= now]
            if not due:
                self.wake.clear()
                timeout = None
                if self.pending:
                    timeout = min(at for at, _ in self.pending.values()) - now
                try:
                    await asyncio.wait_for(self.wake.wait(), timeout)
                except asyncio.TimeoutError:
                    pass
                continue
            for did in due:
                _, updates = self.pending.pop(did)
                name = await asyncio.to_thread(self.names.lookup, did)
                if name is None or name in EXCLUDE:
                    continue
                try:
                    await asyncio.to_thread(mirror, did, name, updates)
                except Exception as error:
                    log.error("mirror %s failed: %s", name, error)

    async def follow(self):
        ws_url = KNOT_URL.replace("http", "ws", 1) + "/events"
        # Start at now: the sweep covers whatever came before.
        cursor = time.time_ns()
        backoff = 1
        while True:
            try:
                url = f"{ws_url}?cursor={cursor}"
                async with websockets.connect(url, max_size=None) as socket:
                    log.info("following %s", ws_url)
                    backoff = 1
                    async for raw in socket:
                        event = json.loads(raw)
                        cursor = max(cursor, int(event.get("created", 0)))
                        if event.get("nsid") != "sh.tangled.git.refUpdate":
                            continue
                        payload = event.get("event", {})
                        if payload.get("ownerDid") not in (None, OWNER_DID):
                            continue
                        did = payload.get("repo")
                        if not did:
                            continue
                        ref = payload.get("ref") or None
                        self.schedule(
                            did,
                            ref=ref,
                            old=payload.get("oldSha"),
                            new=payload.get("newSha"),
                        )
            except Exception as error:
                log.warning("event stream dropped: %s", error)
            await asyncio.sleep(backoff)
            backoff = min(backoff * 2, 60)


async def main():
    logging.basicConfig(level=logging.INFO, format="%(message)s")
    syncer = Syncer()
    await asyncio.gather(syncer.worker(), syncer.sweeper(), syncer.follow())


if __name__ == "__main__":
    asyncio.run(main())
