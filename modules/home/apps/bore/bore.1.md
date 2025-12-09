% BORE(1) bore 1.0
% Kieran Klukas
% December 2024

# NAME

bore - secure tunneling service for exposing local services to the internet

# SYNOPSIS

**bore** [*SUBDOMAIN*] [*PORT*] [**--label** *LABEL*] [**--save**]

**bore** **--list** | **-l**

**bore** **--saved** | **-s**

# DESCRIPTION

**bore** is a tunneling service that uses frp (fast reverse proxy) to expose local services to the internet via bore.dunkirk.sh. It provides a simple CLI for creating and managing HTTP tunnels with optional labels and persistent configuration.

# OPTIONS

**-l**, **--list**
: List all active tunnels on the bore server.

**-s**, **--saved**
: List all saved tunnel configurations from bore.toml in the current directory.

**--label** *LABEL*
: Assign a label/tag to the tunnel for organization and identification.

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
label = "dev"
```

When running **bore** without arguments in a directory with bore.toml, you'll be prompted to choose between creating a new tunnel or using a saved configuration.

# EXAMPLES

Create a simple tunnel:
```
$ bore myapp 8000
```

Create a tunnel with a label:
```
$ bore api 3000 --label dev
```

Save a tunnel configuration:
```
$ bore frontend 5173 --label local --save
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

# BUGS

Report bugs at: https://github.com/yourusername/dots/issues

# AUTHORS

Kieran Klukas <crush@charm.land>
