# cedarplan

Cedarville course planner: a degree audit read in the student's own browser,
and a shared cache of the public section catalog.

**Domain:** `cedarplan.dunkirk.sh` · **Port:** 3008 · **Runtime:** bun ·
**Repo:** [the-cedarville-app](https://github.com/taciturnaxolotl/the-cedarville-app)

## What the server holds, and what it does not

One SQLite file of course sections. No accounts, because there is nothing here
to attach one to: a student's transcript is read by a browser extension, stays
in that browser, and is only ever written to disk by a companion process the
student runs on their own machine.

That is worth stating in a deployment note because it is the only reason this
service needs no secret and no backup of anything personal. The database is
public course data and is rebuildable by any signed-in student, so it is
backed up to save the crawl rather than to protect the contents.

## No secret

`secretsFile` is deliberately unset. The planner authenticates to nothing.

## Environment

| Variable | Value | Why |
|---|---|---|
| `APP_ORIGIN` | `https://cedarplan.dunkirk.sh` | Compiled into the page and the extension manifest. An extension cannot be told at runtime which origins may ask it for a transcript, so the origin is a build input. |
| `CATALOG_DB` | `${dataDir}/data/catalog.sqlite` | WAL mode, so restic copies it hot. |
| `HOST` | `127.0.0.1` | The app binds loopback by default; this is explicit rather than load-bearing. |
| `CRAWL` | `off` | See below. |

## Why `CRAWL=off`

The server used to crawl the course catalog itself, anonymously, from the
public course search. Cedarville put that search behind SSO, so the only
session that can read a timetable now is a signed-in student's browser. The
first student to open a term crawls it there and offers it to this cache;
everybody after them reads the cache.

Left on, the server's own crawl loop fails against a login page every thirty
minutes and achieves nothing but log noise.

## The one open write route

`POST /catalog/<term>/ingest` takes a crawl from whoever is signed in, because
that is now the only way the cache can be filled. It is unauthenticated by
design and guarded on the claim rather than the claimant:

- every section validated field by field, one bad section refusing the batch
- the crawl must say it reached the last page, or it may not replace a term
- a crawl may not shrink a term by more than a fifth
- every section must belong to the term it was posted under
- the term must be a code the registrar could issue, in a plausible year

Caddy caps the body at 32MB, which clears a real term's crawl with room to
spare. A determined student can still post a plausible lie about the catalog;
what they cannot do is delete it or grow it without bound.

## The extension

The planner serves `/install.html` and `cedarville-bridge.zip`, built from the
same source tree as the page. Chrome refuses to install an extension from a
web page, so a student unzips it and loads it unpacked. The page asks the
installed extension for its version at startup and says so when it is older
than the planner, which is the failure that otherwise reads as the planner
being broken.

## Deploys

The app repo's `.github/workflows/deploy.yml` calls the reusable workflow with
no `build_command`, on purpose: `bun start` builds and then serves, so the
build happens inside the unit where `APP_ORIGIN` is set. A build in the deploy
workflow's SSH shell would bake in `localhost`.
