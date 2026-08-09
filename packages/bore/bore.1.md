% BORE(1) bore
% Kieran Klukas
% August 2026

# NAME

bore - expose a local port to the internet

# SYNOPSIS

**bore** [*NAME*] [*PORT*] [**-p** *PROTOCOL*] [**--label** *LABEL*]... [**-a**] [**--save**] [**-v**]

**bore** **-l** | **--list**

**bore** **-s** | **--saved**

# DESCRIPTION

**bore** exposes a local port to the internet through a tunnelling service built on frp.

Give a name and a port and the tunnel opens straight away. Leave them out and **bore** asks, offering the tunnels saved in **bore.toml** if the directory has any. A name that matches a saved tunnel runs that one, so **bore api** is enough once **api** has been saved.

An http tunnel is published at *NAME*.bore.dunkirk.sh. A tcp or udp tunnel gets a port allocated by the server, which **bore** prints once the tunnel is up.

The tunnel lasts as long as the command runs. Stop it with ctrl-c.

# OPTIONS

**-p**, **--protocol** *PROTOCOL*
: Tunnel protocol: **http** (default), **tcp** or **udp**.

**--label** *LABEL*
: Label the tunnel. Repeatable, or comma separated. Labels show up in **--list** and on the status page.

**-a**, **--auth**
: Require an Indiko sign-in before anyone reaches the tunnel. Without it the tunnel is open to whoever has the URL.

**--save**
: Save this tunnel to **bore.toml** so it can be run by name later. Only that tunnel's lines are rewritten; the rest of the file, comments included, is left alone.

**-l**, **--list**
: List the tunnels currently running on the server, whoever started them.

**-s**, **--saved**
: List the tunnels saved in this directory's **bore.toml**.

**--no-inspect**
: Point the tunnel straight at the local port instead of through bore. Traffic stops being listed; use it if the extra hop is in the way.

**-v**, **--verbose**
: Pass frpc's own logs through untouched. Without it bore keeps frpc at warning level and reports what happens in its own words.

**-h**, **--help**
: Show help and exit.

**--version**
: Show the version and exit.

# INSPECTING TRAFFIC

bore sits between the tunnel and the service and reports what goes through. For an http tunnel that is a line per request:

    15:04:12  GET      /                                        200    4ms  1.2 kB
    15:04:13  GET      /static/app.css                          200    1ms   14 kB
    15:04:19  POST     /api/login                               401   22ms    87 B

The columns are sized to the widest thing that can land in them, and a narrow terminal drops them from the right: the byte count first, then the duration, then the timestamp, so what happened and how it went survive to the end. Status codes are coloured by class. The lines are printed into normal scrollback with the tunnel's details pinned below them, so scrolling back through a session works as it would for any other command. Requests are only visible to something on the path, which is why the tunnel points at bore rather than at the service; **--no-inspect** removes the hop and the listing with it.

tcp and udp carry bytes with no requests in them, so what gets reported is the shape of the traffic rather than its content: one line per conversation, with how long it lasted and how much went each way.

    15:04:12  tcp      ↑ 1.4 kB  ↓ 22.0 kB                       ok   1.2s   23 kB
    15:04:31  udp      18 datagrams                              ok   4.0s  2.1 kB

A tcp conversation ends when either side hangs up. udp has no such thing, so a conversation is one source address until it goes quiet for thirty seconds. While conversations are held open the status line counts them, which for a database or an ssh session is most of what there is to say.

A tcp or udp tunnel is published on a port the server picks, so the **public** row arrives once the tunnel is up rather than with the rest of the details.

# CONFIGURATION

**bore.toml** holds a table per tunnel, named by the tunnel. It is meant to be committed alongside the code it exposes, so a project carries its own tunnels.

```toml
[myapp]
port = 8000

[api]
port = 3000
labels = ["dev", "api"]

[admin]
port = 3001
auth = true

[database]
port = 5432
protocol = "tcp"
```

**port**
: The local port to expose. Required.

**protocol**
: **http**, **tcp** or **udp**. Defaults to http and is only written when it is something else.

**labels**
: A list of labels. A single **label = "dev"** is also read, for files written by older versions.

**auth**
: **true** requires an Indiko sign-in.

# EXAMPLES

Expose a dev server:

    bore myapp 8000

Behind a sign-in, and remembered for next time:

    bore admin 3001 --auth --save

Then later, from the same directory:

    bore admin

A database over tcp, where the server picks the public port:

    bore db 5432 --protocol tcp

See what is running, and what this project has saved:

    bore --list
    bore --saved

# FILES

*bore.toml*
: Saved tunnels for the current directory.

# EXIT STATUS

**0**
: The tunnel closed cleanly.

**1**
: The tunnel could not be set up.

**130**
: Interrupted.

# SEE ALSO

**frpc**(1)

Status page: https://bore.dunkirk.sh
