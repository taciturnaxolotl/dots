# Writing a template

A template is a directory in here. Drop one in, and it shows up in the picker,
in `--template`, and in shell completion. There is nothing to register.

```
templates/
  hardware/
    template.toml        what this template is and what it asks about
    README.md.tmpl       rendered
    .gitignore           copied verbatim
    hardware/.gitignore  nested paths are created as needed
```

Files ending in `.tmpl` are rendered as Go templates and lose the suffix.
Everything else is copied byte for byte. Existing files are never overwritten;
a run reports them as already there and leaves them alone.

Preview without creating anything:

```
ghrpc template list
ghrpc template render hardware /tmp/preview
```

## template.toml

```toml
type = "hardware"                     # groups templates in the picker
order = 2                             # lower sorts first; unset sorts last
description = "KiCad, firmware, CAD and docs layout"

[[licence]]
key = "hardware"                      # names the row and the -l flag: -l hardware=...
section = "Hardware"                  # heading in LICENSE.md; prompt is "<section> licence"
covers = "Hardware design files"      # the summary line in LICENSE.md
path = "hardware/LICENSE.md"          # optional: standalone copy with --split-licenses
options = ["CERN-OHL-S-2.0", "MIT"]   # best default first
```

Every `[[licence]]` block is one question the form asks and one section of
`LICENSE.md`. A template with a single block gets a plain one-licence file;
several blocks get a summary and one section each. `section` and `covers` are
only needed when there is more than one.

Licence ids must exist in `licenses/licenses.toml`. A typo fails the build, not
someone's repo.

## What a template can use

| | |
|---|---|
| `{{.Name}}` | repository name |
| `{{.Description}}` | one-line description, may be empty |
| `{{.Year}}` | current year |
| `{{.Owner}}` `{{.OwnerURL}}` | who the copyright belongs to |
| `{{.Branch}}` | default branch |
| `{{.Canonical}}` | the repo's home URL |
| `{{.CanonicalForge}}` | which forge that is, e.g. `tangled` |
| `{{.Forges}}` | every forge published to; `{{if gt (len .Forges) 1}}` for the both case |
| `{{.GitHubUser}}` `{{.TangledDomain}}` | account names, when a URL has to be built by hand |
| `{{.Root}}` | `../` per level down, for links back to the repo root |
| `{{(.Lic "hardware").Badge}}` | the licence chosen for a slot: `.ID`, `.Name`, `.Badge`, `.Description` |

`ghrpc template render` fills all of these in, so a preview shows what a real
run would produce.

## Licences

A licence is three things in `licenses/`:

1. `<id>.md.tmpl` — the body, rendered into `LICENSE.md`. No heading; the
   composer adds it.
2. an entry in `licenses.toml` — name, one-line description for the picker, and
   the badge text.
3. optionally `texts/<file>` plus `text = "<file>"` in the entry, for licences
   whose full text should travel with the repo (the CERN OHL family).

## What is checked

`go test` walks the whole tree and fails the build on: a malformed
`template.toml`, an unknown licence id, a slot with no options, a path escaping
the repo, a `.tmpl` that does not parse or render, a licence missing its body or
declared text, and OS junk like `.DS_Store` sneaking into the embed.
