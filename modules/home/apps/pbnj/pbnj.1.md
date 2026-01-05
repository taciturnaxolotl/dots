% PBNJ(1) pbnj 1.0
% 
% January 2026

# NAME

pbnj - pastebin CLI

# SYNOPSIS

**pbnj** [*OPTIONS*] [*FILE*]

**cat** *file* | **pbnj**

# DESCRIPTION

**pbnj** is a command-line interface for uploading and managing code snippets on a pbnj pastebin instance.

# COMMANDS

**init**
: Configure pbnj instance (host URL and auth key).

**config**
: Show current configuration.

**list** [*n*]
: List recent pastes (default: 10). Interactive selection to copy URL.

**delete** *id*
: Delete a specific paste.

**delete-all**
: Delete all pastes (with confirmation).

# OPTIONS

**-L**, **--language** *lang*
: Override automatic language detection.

**-f**, **--filename** *name*
: Set custom filename for the paste.

**-p**, **--private**
: Create private/unlisted paste.

**-k**, **--key** *key*
: Add secret key to paste.

**-u**, **--update** *id*
: Update an existing paste by ID.

**-n**, **--no-copy**
: Don't automatically copy URL to clipboard.

**-l**, **--list** [*n*]
: List recent pastes.

**-h**, **--help**
: Show help message.

# EXAMPLES

Upload a file:

    pbnj script.py

Pipe content:

    cat file.txt | pbnj

Upload with custom language:

    pbnj -L rust main.rs

Create private paste:

    pbnj -p secret.txt

Update existing paste:

    pbnj -u crunchy-peanut updated.py

List recent pastes:

    pbnj list 20

# CONFIGURATION

Configuration is stored in **~/.pbnj.json** or can be set via environment variables:

**PBNJ_HOST**
: The pbnj instance URL.

**PBNJ_AUTH_KEY**
: Authentication key.

**PBNJ_CONFIG**
: Override config file path.

# SEE ALSO

**curl**(1), **jq**(1)
