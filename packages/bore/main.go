package main

import (
	"context"
	"fmt"
	"os"
	"os/signal"
	"regexp"
	"syscall"

	"github.com/charmbracelet/fang"
	"github.com/spf13/cobra"
)

// Defaults baked in at build time via -ldflags -X, from the home-manager module.
var (
	serverAddr = "bore.dunkirk.sh"
	// A string because -X can only set string vars; parsed on use.
	serverPort    = "7000"
	domain        = "bore.dunkirk.sh"
	authTokenFile = ""

	version = "dev"

	frpcBin = "frpc"
)

var (
	// Subdomains become part of a hostname, so they are limited to what a
	// hostname label may contain.
	validSubdomain = regexp.MustCompile(`^[a-z0-9-]+$`)
	protocols      = []string{"http", "tcp", "udp"}
)

func main() {
	ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer cancel()

	// Stopping a tunnel with ctrl-c is how tunnels end, not an error worth a
	// red box.
	if err := fang.Execute(ctx, newRootCmd(),
		fang.WithVersion(version),
		fang.WithColorSchemeFunc(fang.AnsiColorScheme),
		// The man page is written by hand and installed by the derivation.
		fang.WithoutManpage(),
	); err != nil {
		os.Exit(1)
	}
}

func newRootCmd() *cobra.Command {
	var (
		opts       tunnelOptions
		list       bool
		saved      bool
		labelFlags []string
	)

	cmd := &cobra.Command{
		Use:   "bore [NAME] [PORT]",
		Short: "Expose a local port through bore",
		// One line per paragraph: the man page generator treats every newline
		// as a paragraph break.
		Long: `Expose a local port to the internet through bore, a tunnelling service built on frp.

Give a name and a port to open a tunnel straight away. Leave them out and bore asks, offering the tunnels saved in bore.toml if there are any.

An http tunnel is published at NAME.` + domain + `. A tcp or udp tunnel gets a port allocated by the server, which bore prints once the tunnel is up.`,
		Example: `  bore myapp 8000                    # https://myapp.` + domain + `
  bore api 3000 --auth               # behind Indiko sign-in
  bore db 5432 --protocol tcp        # server allocates a public port
  bore myapp 8000 --save             # remember it in bore.toml
  bore                               # pick from bore.toml, or answer prompts`,
		Args:          cobra.MaximumNArgs(2),
		SilenceErrors: true,
		SilenceUsage:  true,
		RunE: func(cmd *cobra.Command, args []string) error {
			switch {
			case list:
				return runList()
			case saved:
				return runSaved()
			}

			for _, label := range labelFlags {
				opts.labels = append(opts.labels, splitLabels(label)...)
			}
			if len(args) > 0 {
				opts.name = args[0]
			}
			if len(args) > 1 {
				port, err := parsePort(args[1])
				if err != nil {
					return err
				}
				opts.port = port
			}
			opts.protocolGiven = cmd.Flags().Changed("protocol")
			opts.labelsGiven = cmd.Flags().Changed("label")
			opts.authGiven = cmd.Flags().Changed("auth")

			return runTunnel(cmd.Context(), opts)
		},
	}

	f := cmd.Flags()
	f.BoolVarP(&list, "list", "l", false, "list the tunnels currently running on the server")
	f.BoolVarP(&saved, "saved", "s", false, "list the tunnels saved in "+ConfigFile)
	f.StringVarP(&opts.protocol, "protocol", "p", "", "tunnel protocol ("+listOr(protocols)+")")
	f.StringArrayVar(&labelFlags, "label", nil, "label the tunnel; repeatable, or comma-separated")
	f.BoolVarP(&opts.auth, "auth", "a", false, "require Indiko sign-in to reach the tunnel")
	f.BoolVar(&opts.save, "save", false, "save this tunnel to "+ConfigFile)
	f.BoolVarP(&opts.verbose, "verbose", "v", false, "pass frpc's own logs through untouched")
	f.BoolVar(&opts.rewriteHost, "rewrite-host", false, "send the local service a Host it recognises, for dev servers that refuse unfamiliar ones")
	f.BoolVar(&opts.noInspect, "no-inspect", false, "do not show requests; point the tunnel straight at the port")

	cmd.MarkFlagsMutuallyExclusive("list", "saved")

	_ = cmd.RegisterFlagCompletionFunc("protocol",
		func(*cobra.Command, []string, string) ([]string, cobra.ShellCompDirective) {
			return protocols, cobra.ShellCompDirectiveNoFileComp
		})

	// The first argument is a tunnel name, so complete it from bore.toml.
	cmd.ValidArgsFunction = func(_ *cobra.Command, args []string, _ string) ([]string, cobra.ShellCompDirective) {
		if len(args) > 0 {
			return nil, cobra.ShellCompDirectiveNoFileComp
		}
		cfg, err := LoadConfig()
		if err != nil {
			return nil, cobra.ShellCompDirectiveNoFileComp
		}
		return cfg.Names(), cobra.ShellCompDirectiveNoFileComp
	}

	return cmd
}

func parsePort(s string) (int, error) {
	var port int
	if _, err := fmt.Sscanf(s, "%d", &port); err != nil || port < 1 || port > 65535 {
		return 0, fmt.Errorf("invalid port %q", s)
	}
	return port, nil
}

func listOr(values []string) string {
	switch len(values) {
	case 0:
		return ""
	case 1:
		return values[0]
	}
	out := values[0]
	for _, v := range values[1 : len(values)-1] {
		out += ", " + v
	}
	return out + " or " + values[len(values)-1]
}
