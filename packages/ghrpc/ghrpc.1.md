% GHRPC(1) ghrpc
% Kieran Klukas
% August 2026

# NAME

ghrpc - create a repository on Tangled and GitHub, with a project scaffold

# SYNOPSIS

**ghrpc** [*NAME*] [**-d** *DESCRIPTION*] [**-p**|**--private**] [**-T** *TEMPLATE*] [**-l** [*SLOT*=]*LICENCE*]...

**ghrpc** **template** **list**

**ghrpc** **template** **render** *TEMPLATE* *DIR*

**ghrpc** **shell** zsh|bash|fish

# DESCRIPTION

**ghrpc** creates a repository on Tangled and on GitHub, wires up the git remotes, writes a project scaffold from an embedded template, and pushes the first commit.

Anything not given on the command line is asked for in a form, so running **ghrpc** with no arguments walks through the whole thing. Give every answer as a flag and it runs without prompting, which is what happens automatically when stdin is not a terminal.

Remotes are wired as **origin** pointing at the knot over ssh and **github** pointing at GitHub. A GitHub-only repo gets GitHub as **origin** instead, so the branch always has an upstream.

Run inside a repository that already has remotes, **ghrpc** creates nothing. It reports what is there, offers to add whatever the template provides that the repository is missing, and leaves every existing file alone.

# OPTIONS

**-d**, **--description** *DESCRIPTION*
: One-line description. Used on both forges and written into the README.

**-p**, **--public**
: Make the repository public. This is the default.

**--private**
: Make the repository private.

**-g**, **--github-only**
: Create on GitHub only. GitHub becomes **origin**.

**-t**, **--tangled-only**
: Create on Tangled only.

**--no-github**
: Skip GitHub. May be combined with **--no-tangled** to set up a purely local repository.

**--no-tangled**
: Skip Tangled.

**-T**, **--template** *TEMPLATE*
: Scaffold to write. Use **none** for no files at all. See **TEMPLATES**.

**-l**, **--license** [*SLOT*=]*LICENCE*
: Licence to use. Repeatable. Unqualified, it applies to the template's first licence slot; qualified as *SLOT*=*LICENCE* it applies to that slot, so a hardware repository takes **-l hardware=CERN-OHL-W-2.0 -l firmware=MIT**. See **LICENCES**.

**--split-licenses**
: Also write a standalone LICENSE.md into each licensed directory, so a directory carries its own terms if it is taken away on its own. The root LICENSE.md stays authoritative.

**--plc** *ID*
: PLC identity to create the Tangled repository under.

**--domain** *DOMAIN*
: Tangled domain the repository is published to.

**-h**, **--help**
: Show help and exit.

**-v**, **--version**
: Show the version and exit.

# COMMANDS

**template list**
: List the templates, the project type each belongs to, and the licences each of its slots offers.

**template render** *TEMPLATE* *DIR*
: Render a template into a directory and print the resulting tree. Nothing is created, committed or pushed, and no forge is contacted. This is the way to look at a template, or to iterate on one while writing it.

**shell** zsh|bash|fish
: Print the shell integration. A child process cannot change its parent's working directory, so following the new repository has to happen in the shell; source this to get a wrapper that does it. See **ENVIRONMENT**.

**completion** *SHELL*
: Print the shell completion script.

# TEMPLATES

A template is a directory embedded in the binary. Each one declares a project type, so the form asks what kind of project this is before it asks which template, and a type with a single template skips the second question.

Files ending in **.tmpl** are rendered as Go templates and lose the suffix; everything else is copied byte for byte. Existing files are never overwritten. A run that finds a file already present reports it and moves on, which is what makes **ghrpc** safe to run again over a repository that already has work in it.

The templates shipped are:

**default**
: A README and a licence. Project type *software*.

**hardware**
: An open hardware layout: **hardware/** for the KiCad project, **firmware/**, **cad/** and **docs/**, each with its own .gitignore, plus a JOURNAL-free README carrying licence badges. Project type *hardware*.

# LICENCES

A template declares a licence slot for each part of the repository that needs licensing. The **default** template has one. The **hardware** template has three, because an open hardware project licenses its board, its firmware and its documentation on different terms: typically a CERN OHL variant for the design files, an OSI licence for the firmware, and a Creative Commons licence for the documentation.

Each slot is one question in the form and one section of LICENSE.md. A single slot produces a plain one-licence file; several produce a summary followed by a section each. Slots that land on the same licence share a line in the output.

Licences whose terms are not canonically hosted elsewhere ship their full text alongside LICENSE.md. Choosing CERN-OHL-S-2.0 writes cern_ohl_s_v2.txt, and the licence notice quotes the repository URL as the Source Location, which the CERN licences require.

# FILES

*/run/agenix/bluesky*
: atproto credentials, read to authenticate against the PDS when creating on Tangled. Without it the Tangled row reports the missing file and the run continues.

*LICENSE.md*
: Composed from the template's licence slots.

*template.toml*
: Inside a template directory: what the template is and what it asks about. Not written into the repository.

# ENVIRONMENT

**GHRPC_DIR_FILE**
: If set, the final directory is written to this path on exit. The shell integration from **ghrpc shell** uses it to cd into the new repository.

# EXAMPLES

Walk through everything:

    ghrpc

Name and describe it up front, answer the rest in the form:

    ghrpc canopy -d "a CAN bus HAT for the Pi"

A hardware repository, licensed for a module meant to be embedded in someone else's product:

    ghrpc melty -T hardware -l hardware=CERN-OHL-W-2.0 -l firmware=MIT -l docs=CC-BY-4.0

A private scratch repository on GitHub only, no files:

    ghrpc scratch --github-only --private --template none

Look at a template without creating anything:

    ghrpc template render hardware /tmp/preview

# EXIT STATUS

**0**
: The repository was set up. Individual steps that failed are reported on their own line, in red, with the reason.

**1**
: The run could not proceed.

**130**
: Interrupted at a prompt.

# SEE ALSO

**git**(1), **gh**(1)

Tangled: https://tangled.org
