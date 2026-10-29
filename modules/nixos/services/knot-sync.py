"""Mirror a knot's repos to GitHub, driven by its firehose plus periodic sweeps.

GitHub also gets its own commits (dependabot, release bots, merged PRs), so
sweeps only fast-forward; deletes and force-pushes only follow a knot push
event, leased on the SHA that push replaced.
"""

import asyncio
import io
import json
import logging
import os
import subprocess
import urllib.error
import urllib.parse
import urllib.request

import cbor2
import websockets

KNOT_URL = os.environ["KNOT_URL"].rstrip("/")
OWNER_DID = os.environ["OWNER_DID"]
GITHUB_USERNAME = os.environ["GITHUB_USERNAME"]
GITHUB_URL = os.environ.get("GITHUB_URL", "https://github.com/{user}/{name}.git")
STATE_DIRECTORY = os.environ["STATE_DIRECTORY"]
EXCLUDE = set(filter(None, os.environ.get("EXCLUDE", "").split(",")))
SWEEP_SECS = int(os.environ.get("SWEEP_SECS", "21600"))
PUSH_EVENT = "org.tangled.git.pushEvent"
FETCH_REFSPECS = ["+refs/heads/*:refs/heads/*", "+refs/tags/*:refs/tags/*"]
FF_REFSPECS = ["refs/heads/*:refs/heads/*", "refs/tags/*:refs/tags/*"]
# Reads the token from the environment so it never lands in argv or on disk.
CREDENTIAL_HELPER = "!f() { echo username=$GITHUB_USERNAME; echo password=$GITHUB_TOKEN; }; f"

log = logging.getLogger("knot-sync")


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


def owned_name(did):
    """The repo's name if the owner holds it, from its manifest on the knot."""
    try:
        record = knot_xrpc(
            "com.atproto.repo.getRecord",
            repo=did, collection="org.tangled.repo.manifest", rkey="self",
        )
    except urllib.error.HTTPError:
        return None
    declaration = record["value"]["declaration"]
    return declaration["name"] if declaration["owner"] == OWNER_DID else None


def git(*args, cwd=None, check=True):
    result = subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True)
    if check and result.returncode != 0:
        raise RuntimeError(f"git {args[0]} failed: {result.stderr.strip()[-2000:]}")
    return result


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
        raise RuntimeError(f"push failed: {result.stderr.strip()[-2000:]}")
    for flag, refs, summary in lines:
        ref = refs.split(":", 1)[-1]
        if flag == "!":
            log.warning("%s: left %s alone on GitHub (%s)", name, ref, summary)
        elif flag != "=":
            log.info("%s: %s %s", name, ref, summary)


def mirror(did, edits):
    name = owned_name(did)
    if name is None or name in EXCLUDE:
        return
    path = os.path.join(STATE_DIRECTORY, "mirrors", f"{did}.git")
    if os.path.isdir(path):
        git("fetch", "--quiet", "--prune", "origin", *FETCH_REFSPECS, cwd=path)
    else:
        git("clone", "--quiet", "--mirror", f"{KNOT_URL}/{did}", path)

    for edit in edits:
        ref, old, new = edit["name"], edit.get("old"), edit.get("new")
        if old is None:
            continue
        fast_forward = new is not None and git(
            "merge-base", "--is-ancestor", old, new, cwd=path, check=False
        ).returncode == 0
        if not fast_forward:
            push(path, name, f"+{ref}:{ref}" if new else f":{ref}", lease=f"{ref}:{old}")

    push(path, name, *FF_REFSPECS)


def decode_frame(raw):
    """A firehose frame is two DAG-CBOR objects back to back: header, body."""
    decoder = cbor2.CBORDecoder(io.BytesIO(raw))
    header = decoder.decode()
    try:
        return header, decoder.decode()
    except cbor2.CBORDecodeEOF:
        return header, {}


async def worker(queue):
    while True:
        did, edits = await queue.get()
        try:
            await asyncio.to_thread(mirror, did, edits)
        except Exception as error:
            log.error("mirror %s failed: %s", did, error)


async def sweeper(queue):
    while True:
        try:
            for did in await asyncio.to_thread(lambda: list(hosted_repos())):
                queue.put_nowait((did, []))
        except Exception as error:
            log.error("sweep failed: %s", error)
        await asyncio.sleep(SWEEP_SECS)


async def follow(queue):
    url = KNOT_URL.replace("http", "ws", 1) + "/xrpc/com.atproto.sync.subscribeRepos"
    # The first connect starts live (the sweep covers the past); reconnects resume.
    cursor, backoff = None, 1
    while True:
        try:
            resume = f"?cursor={cursor}" if cursor else ""
            async with websockets.connect(url + resume, max_size=None) as socket:
                log.info("following %s", url)
                backoff = 1
                async for raw in socket:
                    header, body = decode_frame(raw)
                    if header.get("op") != 1:
                        log.warning("firehose error frame: %s", body)
                        cursor = None
                        break
                    cursor = body.get("seq", cursor)
                    if header.get("t") == PUSH_EVENT:
                        queue.put_nowait((body["repo"], body.get("edits", [])))
        except Exception as error:
            log.warning("firehose dropped: %s", error)
        await asyncio.sleep(backoff)
        backoff = min(backoff * 2, 60)


async def main():
    logging.basicConfig(level=logging.INFO, format="%(message)s")
    queue = asyncio.Queue()
    await asyncio.gather(worker(queue), sweeper(queue), follow(queue))


if __name__ == "__main__":
    asyncio.run(main())
