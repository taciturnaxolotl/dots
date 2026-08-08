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

// Defaults and tool paths, overridden at build time via -ldflags -X.
var (
	defaultPLCID      = "did:plc:krxbvxvis5skq7jj6eot23ul"
	defaultGitHubUser = "taciturnaxolotl"
	defaultKnotHost   = "knot.dunkirk.sh"
	defaultDomain     = "dunkirk.sh"
	defaultBranch     = "main"
	defaultCredsFile  = "/run/agenix/bluesky"
	defaultOwner      = "Kieran Klukas"
	defaultOwnerURL   = "https://dunkirk.sh"

	version = "dev"

	gitBin = "git"
	ghBin  = "gh"

	// Used only in the generated shell integration.
	mktempBin = "mktemp"
	rmBin     = "rm"
	catBin    = "cat"
)

type config struct {
	plcID           string
	githubUser      string
	knotHost        string
	domain          string
	branch          string
	credentialsFile string
}

var validName = regexp.MustCompile(`^[a-zA-Z0-9._-]+$`)

func main() {
	ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer cancel()

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
	cfg := config{
		plcID:           defaultPLCID,
		githubUser:      defaultGitHubUser,
		knotHost:        defaultKnotHost,
		domain:          defaultDomain,
		branch:          defaultBranch,
		credentialsFile: defaultCredsFile,
	}

	var (
		opts       = options{useGitHub: true, useTangled: true}
		set        given
		public     bool
		private    bool
		githubOnly bool
		tangledOly bool
		noGitHub   bool
		noTangled  bool
	)

	cmd := &cobra.Command{
		Use:   "ghrpc [NAME]",
		Short: "Create repositories on GitHub and Tangled",
		// One line per paragraph: the man page generator treats every newline
		// as a paragraph break, so hard-wrapping here shreds the output.
		Long: `Create repositories on GitHub and Tangled with git remotes configured and an optional project scaffold written from an embedded template.

Remotes are wired as origin -> knot (ssh) and github -> GitHub. A GitHub-only repo gets GitHub as origin instead.

Templates are embedded in the binary. Each one declares a project type and a licence slot for every part of the repo that needs licensing, so a hardware project picks its hardware, firmware and documentation licences separately and LICENSE.md is composed from them.`,
		Example: `  ghrpc                                  # prompts for everything
  ghrpc canopy -d "a CAN bus HAT"        # named, still prompts for the rest
  ghrpc melty --template hardware        # scaffold a hardware repo
  ghrpc scratch --github-only --template none`,
		Args:          cobra.MaximumNArgs(1),
		SilenceErrors: true,
		SilenceUsage:  true,
		RunE: func(cmd *cobra.Command, args []string) error {
			if len(args) == 1 {
				opts.name = args[0]
			}
			if private {
				opts.visibility = "private"
			} else if public {
				opts.visibility = "public"
			}
			if githubOnly || noTangled {
				opts.useTangled = false
			}
			if tangledOly || noGitHub {
				opts.useGitHub = false
			}

			set.description = cmd.Flags().Changed("description")
			set.visibility = public || private
			set.target = githubOnly || tangledOly || noGitHub || noTangled
			set.scaffold = cmd.Flags().Changed("template")
			set.licenses = cmd.Flags().Changed("license")
			set.splitFiles = cmd.Flags().Changed("split-licenses")

			return run(cfg, &opts, set)
		},
	}

	f := cmd.Flags()
	f.StringVarP(&opts.description, "description", "d", "", "repository description")
	f.BoolVarP(&public, "public", "p", false, "make the repository public (default)")
	f.BoolVar(&private, "private", false, "make the repository private")
	f.BoolVarP(&githubOnly, "github-only", "g", false, "only create on GitHub")
	f.BoolVarP(&tangledOly, "tangled-only", "t", false, "only create on Tangled")
	f.BoolVar(&noGitHub, "no-github", false, "skip GitHub")
	f.BoolVar(&noTangled, "no-tangled", false, "skip Tangled")
	f.StringVarP(&opts.scaffold, "template", "T", "", "scaffold to write ("+listOr(append(scaffolds(), noScaffold))+")")
	f.StringArrayVarP(&set.licenceFlags, "license", "l", nil, "licence to use, or slot=licence for hardware repos ("+listOr(licenses())+")")
	f.BoolVar(&opts.splitFiles, "split-licenses", false, "also write a LICENSE.md into each licensed directory")
	f.StringVar(&cfg.plcID, "plc", cfg.plcID, "PLC ID for the knot")
	f.StringVar(&cfg.domain, "domain", cfg.domain, "Tangled domain")

	cmd.MarkFlagsMutuallyExclusive("public", "private")
	cmd.MarkFlagsMutuallyExclusive("github-only", "tangled-only")

	cmd.AddCommand(newShellCmd(), newTemplateCmd())

	_ = cmd.RegisterFlagCompletionFunc("template", completeFrom(append(scaffolds(), noScaffold)))
	_ = cmd.RegisterFlagCompletionFunc("license", completeFrom(licenses()))

	return cmd
}

func completeFrom(values []string) func(*cobra.Command, []string, string) ([]string, cobra.ShellCompDirective) {
	return func(*cobra.Command, []string, string) ([]string, cobra.ShellCompDirective) {
		return values, cobra.ShellCompDirectiveNoFileComp
	}
}

func listOr(values []string) string {
	switch len(values) {
	case 0:
		return ""
	case 1:
		return values[0]
	}
	return fmt.Sprintf("%s or %s",
		joinComma(values[:len(values)-1]), values[len(values)-1])
}

func joinComma(values []string) string {
	out := values[0]
	for _, v := range values[1:] {
		out += ", " + v
	}
	return out
}

// applyNonInteractiveDefaults fills in what the form would have asked for.
func applyNonInteractiveDefaults(opts *options) {
	if opts.name == "" && inWorkTree() {
		opts.name = repoName()
	}
	if opts.visibility == "" {
		opts.visibility = "public"
	}
	if opts.scaffold == "" {
		opts.scaffold = noScaffold
	}
}
