% ANTHROPIC-MANAGER(1) | Anthropic OAuth Profile Manager
% Kieran Klukas
% December 2024

# NAME

anthropic-manager - Manage Anthropic OAuth credential profiles

# SYNOPSIS

**anthropic-manager** [*OPTIONS*]

**anthropic-manager** **--init** [*PROFILE*]

**anthropic-manager** **--swap** [*PROFILE*]

**anthropic-manager** **--delete** [*PROFILE*]

**anthropic-manager** **--token**

**anthropic-manager** **--list**

**anthropic-manager** **--current**

# DESCRIPTION

**anthropic-manager** is a tool for managing multiple Anthropic OAuth credential profiles. It implements PKCE-based OAuth authentication with automatic token refresh, allowing you to switch between different Anthropic accounts easily.

Profile credentials are stored in **~/.config/crush/anthropic.\***profile\* directories with individual bearer tokens, refresh tokens, and expiration timestamps.

# OPTIONS

**--init**, **-i** [*PROFILE*]
: Initialize a new OAuth profile. Opens browser for authentication and stores credentials.

**--swap**, **-s** [*PROFILE*]
: Switch to a different profile. If no profile specified, shows interactive selection.

**--delete**, **-d** [*PROFILE*]
: Delete a profile and its credentials. If no profile specified, shows interactive selection. Prompts for confirmation before deletion. If the deleted profile is active, the symlink is removed.

**--token**, **-t**
: Print the current bearer token to stdout. Automatically refreshes if expired. Designed for non-interactive use.

**--list**, **-l**
: List all available profiles with their status (valid/expired/invalid).

**--current**, **-c**
: Show the currently active profile name.

**--help**, **-h**
: Display help information.

# INTERACTIVE MENU

When run without arguments in an interactive terminal, **anthropic-manager** displays a menu with the following options:

- Switch profile
- Create new profile
- Delete profile
- List all profiles
- Get current token

# PROFILE STORAGE

Profiles are stored in **~/.config/crush/** with the following structure:

```
~/.config/crush/
├── anthropic -> anthropic.work   (symlink to active profile)
├── anthropic.work/
│   ├── bearer_token              (OAuth access token, mode 600)
│   ├── bearer_token.expires      (Unix timestamp)
│   └── refresh_token             (OAuth refresh token, mode 600)
└── anthropic.personal/
    └── ...
```

The active profile is determined by the **anthropic** symlink.

# ENVIRONMENT

**ANTHROPIC_CONFIG_DIR**
: Override the default configuration directory (~/.config/crush).

# EXIT STATUS

**0**
: Success

**1**
: Error (no active profile, authentication failed, invalid token, etc.)

# EXAMPLES

Initialize a new work profile:

```
$ anthropic-manager --init work
```

Switch to the work profile:

```
$ anthropic-manager --swap work
```

Delete a profile:

```
$ anthropic-manager --delete work
```

Get the current bearer token (for scripts):

```
$ TOKEN=$(anthropic-manager --token)
```

List all profiles:

```
$ anthropic-manager --list
```

Open interactive menu:

```
$ anthropic-manager
```

# INTEGRATION

**anthropic-manager** is designed to replace **bunx anthropic-api-key** in crush configurations:

```nix
api_key = "Bearer $(anthropic-manager --token)";
```

The **--token** flag automatically handles:
- Loading cached tokens
- Checking expiration (refreshes if <60s remaining)
- Refreshing using refresh token
- Non-interactive operation (errors to stderr, token to stdout)

# FILES

**~/.config/crush/anthropic**
: Symlink to active profile directory

**~/.config/crush/anthropic.*/bearer_token**
: OAuth access token for each profile

**~/.config/crush/anthropic.*/refresh_token**
: OAuth refresh token for each profile

**~/.config/crush/anthropic.*/bearer_token.expires**
: Token expiration timestamp (Unix epoch)

# SEE ALSO

**crush**(1)

# BUGS

Report bugs to: <https://github.com/taciturnaxolotl/dots>

# COPYRIGHT

Copyright © 2024 Kieran Klukas. Licensed under MIT License.
