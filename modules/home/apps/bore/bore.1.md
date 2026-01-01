% BORE(1) bore 1.0
% Kieran Klukas
% January 2026

# NAME

bore - secure tunneling service for exposing local services to the internet

# SYNOPSIS

**bore** [*SUBDOMAIN*] [*PORT*] [**--protocol** *PROTOCOL*] [**--label** *LABEL*] [**--auth**] [**--save**]

**bore** **--list** | **-l**

**bore** **--saved** | **-s**

# DESCRIPTION

**bore** is a tunneling service that uses frp (fast reverse proxy) to expose local services to the internet via bore.dunkirk.sh. It provides a simple CLI for creating and managing HTTP, TCP, and UDP tunnels with optional labels, authentication, and persistent configuration.

# OPTIONS

**-l**, **--list**
: List all active tunnels on the bore server.

**-s**, **--saved**
: List all saved tunnel configurations from bore.toml in the current directory.

**-p**, **--protocol** *PROTOCOL*
: Specify the protocol to use for the tunnel: **http** (default), **tcp**, or **udp**.

**--label** *LABEL*
: Assign a label/tag to the tunnel for organization and identification.

**-a**, **--auth**
: Require Indiko authentication to access the tunnel. Users must sign in via OAuth before accessing the tunneled service.

**--save**
: Save the tunnel configuration to bore.toml in the current directory for future use.

# ARGUMENTS

*SUBDOMAIN*
: The subdomain to use for the tunnel (e.g., "myapp" creates myapp.bore.dunkirk.sh). Must contain only lowercase letters, numbers, and hyphens.

*PORT*
: The local port to expose (e.g., 8000 for localhost:8000).

# CONFIGURATION

Tunnel configurations can be saved to a **bore.toml** file in the current directory. This file uses TOML format and can be committed to repositories.

## bore.toml Format

```toml
[myapp]
port = 8000

[api]
port = 3000
labels = ["dev", "api"]

[admin]
port = 3001
auth = true
labels = ["admin"]

[database]
port = 5432
protocol = "tcp"
labels = ["postgres"]

[game-server]
port = 27015
protocol = "udp"
labels = ["game"]
```

When running **bore** without arguments in a directory with bore.toml, you'll be prompted to choose between creating a new tunnel or using a saved configuration.

# AUTHENTICATION

Tunnels can require Indiko authentication by setting **auth = true** in bore.toml or using the **--auth** flag. When enabled:

- Users are redirected to Indiko to sign in before accessing the tunnel
- Sessions last 7 days by default
- The authenticated user's info is passed to the tunneled service via headers:
  - **X-Auth-User**: User's profile URL
  - **X-Auth-Name**: User's display name
  - **X-Auth-Email**: User's email address

# EXAMPLES

Create a simple HTTP tunnel:
```
$ bore myapp 8000
```

Create an HTTP tunnel with a label:
```
$ bore api 3000 --label dev
```

Create a protected tunnel requiring authentication:
```
$ bore admin 3001 --auth --label admin
```

Create a TCP tunnel for a database:
```
$ bore database 5432 --protocol tcp --label postgres
```

Create a UDP tunnel for a game server:
```
$ bore game-server 27015 --protocol udp --label game
```

Save a tunnel configuration:
```
$ bore frontend 5173 --label local --save
```

Save a protected tunnel configuration:
```
$ bore admin 3001 --auth --label admin --save
```

List active tunnels:
```
$ bore --list
```

List saved configurations:
```
$ bore --saved
```

Interactive mode (choose saved or new):
```
$ bore
```

# FILES

**bore.toml**
: Local tunnel configuration file (current directory)

# SEE ALSO

Dashboard: https://bore.dunkirk.sh

Indiko: https://indiko.dunkirk.sh

# BUGS

Report bugs at: https://github.com/yourusername/dots/issues

# AUTHORS

Kieran Klukas <crush@charm.land>
