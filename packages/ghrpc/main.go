package main

import (
	"context"
	"fmt"
	"os"
	"os/signal"
	"path/filepath"
	"regexp"
	"strings"
	"syscall"
	"time"

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
		opts         = options{useGitHub: true, useTangled: true}
		public       bool
		private      bool
		licenseFlags []string
		githubOnly   bool
		tangledOly   bool
		noGitHub     bool
		noTangled    bool
	)

	cmd := &cobra.Command{
		Use:   "ghrpc [NAME]",
		Short: "Create repositories on GitHub and Tangled",
		Long: `Create repositories on GitHub and Tangled with git remotes configured
and an optional project scaffold written from an embedded template.

Remotes are wired as origin -> knot (ssh) and github -> GitHub. A GitHub-only
repo gets GitHub as origin instead.`,
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

			set := given{
				description: cmd.Flags().Changed("description"),
				visibility:  public || private,
				target:      githubOnly || tangledOly || noGitHub || noTangled,
				scaffold:    cmd.Flags().Changed("template"),
				licenses:    cmd.Flags().Changed("license"),
				splitFiles:  cmd.Flags().Changed("split-licenses"),
			}
			opts.licenses = parseLicenseFlags(licenseFlags, opts.scaffold)
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
	f.StringArrayVarP(&licenseFlags, "license", "l", nil, "licence to use, or slot=licence for hardware repos ("+listOr(licenses())+")")
	f.BoolVar(&opts.splitFiles, "split-licenses", false, "also write a LICENSE.md into each licensed directory")
	f.StringVar(&cfg.plcID, "plc", cfg.plcID, "PLC ID for the knot")
	f.StringVar(&cfg.domain, "domain", cfg.domain, "Tangled domain")

	cmd.MarkFlagsMutuallyExclusive("public", "private")
	cmd.MarkFlagsMutuallyExclusive("github-only", "tangled-only")

	cmd.AddCommand(newShellCmd())

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
	out := ""
	for i, v := range values {
		switch {
		case i == 0:
			out = v
		case i == len(values)-1:
			out += " or " + v
		default:
			out += ", " + v
		}
	}
	return out
}

func run(cfg config, opts *options, set given) error {
	interactive := interactiveSession()
	if interactive {
		ask(opts, set)
	} else {
		applyNonInteractiveDefaults(opts)
	}

	if err := validateName(opts.name); err != nil {
		return fmt.Errorf("invalid repository name: %w", err)
	}

	title(opts.name, opts.description)
	fmt.Println()

	enterRepoDir(opts.name)

	isRepo := inWorkTree()
	hasRemotes := false
	if isRepo {
		out, _ := gitOut("remote")
		hasRemotes = out != ""
	}

	// An existing repo with remotes means we are topping up, not creating.
	skipRemoteCreation := false
	if isRepo && hasRemotes {
		warn("this repo already has remotes")
		for _, line := range remoteLines() {
			rowDim(line.name, "%s", line.url)
		}
		fmt.Println()

		missing := missingFiles()
		if len(missing) > 0 {
			row("missing", "%s", strings.Join(missing, ", "))
			fmt.Println()
			if interactive && !confirm("Continue and add missing files?") {
				return nil
			}
		} else {
			if !interactive {
				return fmt.Errorf("repository already fully configured")
			}
			if !confirm("Reconfigure remotes?") {
				return nil
			}
		}
		skipRemoteCreation = true
	}

	if !isRepo {
		if interactive && dirHasFiles(".") && !confirm("Directory has files but no git repo. Initialize?") {
			return fmt.Errorf("git repository required")
		}
		if err := gitQuiet("init", "-b", cfg.branch); err != nil {
			return fmt.Errorf("failed to initialize git repository: %w", err)
		}
		isRepo = true
		row("init", "%s", cfg.branch)
	}

	if opts.useTangled && !skipRemoteCreation {
		if !fileExists(cfg.credentialsFile) {
			warn("no atproto credentials at %s", cfg.credentialsFile)
		} else {
			var err error
			step("creating on tangled", func() {
				err = createTangledRepo(cfg, opts.name, opts.description)
			})
			if err != nil {
				failure("%v", err)
			} else {
				rowLink("tangled", fmt.Sprintf("https://tangled.org/%s/%s", cfg.domain, opts.name))
			}
		}
	}

	if opts.useGitHub && !skipRemoteCreation {
		var err error
		step("creating on github", func() {
			err = createGitHubRepo(cfg, opts.name, opts.description, opts.visibility)
		})
		if err != nil {
			failure("could not create the GitHub repo")
			fmt.Fprintln(os.Stderr, err)
		} else {
			rowLink("github", fmt.Sprintf("https://github.com/%s/%s", cfg.githubUser, opts.name))
		}
	}

	// Remote layout: origin is the knot when tangled is in play, github rides
	// alongside; a github-only repo gets github as origin.
	githubRemote := "github"
	if !opts.useTangled {
		githubRemote = "origin"
	}
	if isRepo && !skipRemoteCreation && (opts.useTangled || opts.useGitHub) {
		fmt.Println()
		if opts.useTangled {
			setRemote("origin", fmt.Sprintf("git@%s:%s/%s", cfg.knotHost, cfg.plcID, opts.name))
			_ = gitQuiet("config", "branch."+cfg.branch+".remote", "origin")
		}
		if opts.useGitHub {
			setRemote(githubRemote, fmt.Sprintf("git@github.com:%s/%s.git", cfg.githubUser, opts.name))
		}
	}

	created := applyTemplates(cfg, opts, templateData{
		Name:          opts.name,
		Description:   opts.description,
		Year:          time.Now().Year(),
		Owner:         defaultOwner,
		OwnerURL:      defaultOwnerURL,
		GitHubUser:    cfg.githubUser,
		TangledDomain: cfg.domain,
		Branch:        cfg.branch,
		Tangled:       opts.useTangled,
		GitHub:        opts.useGitHub,
	})

	if len(created) > 0 {
		fmt.Println()
		fmt.Println(fileTree(opts.name, created))
		commitAndPush(cfg, created, opts.useTangled, opts.useGitHub, githubRemote)
	}

	summarize(cfg, opts)
	reportDir()
	return nil
}

// applyNonInteractiveDefaults fills in what the form would have asked for.
func applyNonInteractiveDefaults(opts *options) {
	if opts.name == "" && inWorkTree() {
		opts.name = filepath.Base(repoRoot())
	}
	if opts.visibility == "" {
		opts.visibility = "public"
	}
	if opts.scaffold == "" {
		opts.scaffold = noScaffold
	}
	if opts.licenses == nil {
		opts.licenses = map[string]string{}
	}
	// Fall back to each slot's first (recommended) licence.
	for _, slot := range slotsFor(opts.scaffold) {
		if opts.licenses[slot.Key] == "" && len(slot.Licenses) > 0 {
			opts.licenses[slot.Key] = slot.Licenses[0]
		}
	}
}

// parseLicenseFlags accepts "MIT" for a single-slot template and "hardware=..."
// for the multi-slot ones.
func parseLicenseFlags(values []string, scaffold string) map[string]string {
	if len(values) == 0 {
		return nil
	}
	chosen := map[string]string{}
	slots := slotsFor(scaffold)
	for _, value := range values {
		key, license, found := strings.Cut(value, "=")
		if !found {
			if len(slots) > 0 {
				chosen[slots[0].Key] = value
			}
			continue
		}
		chosen[key] = license
	}
	return chosen
}

// summarize closes with what was licensed and where the repo now lives.
func summarize(cfg config, opts *options) {
	fmt.Println()

	// Slots that landed on the same licence share a line: "firmware/docs".
	var licences [][2]string
	slots := slotsFor(opts.scaffold)
	for i := 0; i < len(slots); {
		id := opts.licenses[slots[i].Key]
		keys := []string{slots[i].Key}
		j := i + 1
		for ; j < len(slots) && opts.licenses[slots[j].Key] == id; j++ {
			keys = append(keys, slots[j].Key)
		}
		licences = append(licences, [2]string{strings.Join(keys, "/"), licenseRegistry[id].Name})
		i = j
	}
	if len(licences) > 0 {
		rowGroup(licences)
	}

	if opts.useTangled || opts.useGitHub {
		row("visibility", "%s", opts.visibility)
	}
}

func missingFiles() []string {
	var missing []string
	for _, path := range []string{"README.md", "LICENSE.md"} {
		if !fileExists(path) {
			missing = append(missing, path)
		}
	}
	return missing
}

// enterRepoDir moves into ./NAME unless we are already inside a repo of that name.
func enterRepoDir(name string) {
	if inWorkTree() && filepath.Base(repoRoot()) == name {
		return
	}
	if err := os.MkdirAll(name, 0o755); err != nil {
		fatal("Error: could not create %s: %v", name, err)
	}
	if err := os.Chdir(name); err != nil {
		fatal("Error: could not enter %s: %v", name, err)
	}
}

// applyTemplates writes the license first so the README badge can name it.
// It returns the paths it created.
func applyTemplates(cfg config, opts *options, data templateData) []string {
	if opts.scaffold == "" || opts.scaffold == noScaffold {
		return nil
	}
	var created []string

	// Tangled is the canonical home unless this is a GitHub-only repo. The
	// CERN licences quote it as the Source Location, so it has to be set
	// before anything renders.
	data.RepoURL = fmt.Sprintf("https://tangled.org/%s/%s", cfg.domain, data.Name)
	if data.GitHub && !data.Tangled {
		data.RepoURL = fmt.Sprintf("https://github.com/%s/%s", cfg.githubUser, data.Name)
	}

	slots := slotsFor(opts.scaffold)
	data.Licenses = map[string]licenseInfo{}
	for _, slot := range slots {
		data.Licenses[slot.Key] = licenseRegistry[opts.licenses[slot.Key]]
	}

	if len(slots) > 0 && !fileExists("LICENSE.md") {
		content, err := composeLicense(slots, opts.licenses, data)
		if err != nil {
			failure("Failed to write LICENSE.md: %v", err)
		} else if err := os.WriteFile("LICENSE.md", []byte(content), 0o644); err != nil {
			failure("Failed to write LICENSE.md: %v", err)
		} else {
			created = append(created, "LICENSE.md")
		}
	}
	if opts.splitFiles {
		created = append(created, writeSlotLicenses(slots, opts.licenses, data)...)
	}
	created = append(created, writeLicenseTexts(opts.licenses)...)

	written, err := writeScaffold(opts.scaffold, data)
	if err != nil {
		failure("could not apply the %s template: %v", opts.scaffold, err)
	}
	return append(created, written...)
}

func commitAndPush(cfg config, paths []string, useTangled, useGitHub bool, githubRemote string) {
	if err := gitQuiet(append([]string{"add", "--"}, paths...)...); err != nil {
		failure("could not stage the new files")
		return
	}
	if err := gitQuiet(append([]string{"commit", "-m", "Add project templates", "--"}, paths...)...); err != nil {
		return
	}

	// origin gets -u so the branch tracks it; the secondary github remote gets
	// a plain push so it can never steal the upstream.
	if useTangled && hasRemote("origin") {
		var err error
		step("pushing to origin", func() { err = gitQuiet("push", "-u", "origin", cfg.branch) })
		if err != nil {
			warn("could not push to origin")
		}
	}
	if useGitHub && hasRemote(githubRemote) {
		args := []string{"push"}
		if githubRemote == "origin" {
			args = append(args, "-u")
		}
		args = append(args, githubRemote, cfg.branch)

		var err error
		step("pushing to "+githubRemote, func() { err = gitQuiet(args...) })
		if err != nil {
			warn("could not push to %s", githubRemote)
		}
	}
}

// reportDir writes the final directory to the file named by GHRPC_DIR_FILE, so
// the shell wrapper can cd into the new repo. Handing over a path rather than
// an inherited fd keeps us clear of the runtime's own descriptors.
func reportDir() {
	path := os.Getenv("GHRPC_DIR_FILE")
	if path == "" {
		return
	}
	dir, err := os.Getwd()
	if err != nil {
		return
	}
	_ = os.WriteFile(path, []byte(dir+"\n"), 0o600)
}

func fileExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}

func dirHasFiles(path string) bool {
	entries, err := os.ReadDir(path)
	return err == nil && len(entries) > 0
}

// interactiveSession reports whether a form can actually be drawn: huh reads
// the controlling terminal, so /dev/tty is the real test.
func interactiveSession() bool {
	tty, err := os.OpenFile("/dev/tty", os.O_RDWR, 0)
	if err != nil {
		return false
	}
	tty.Close()
	info, err := os.Stdin.Stat()
	return err == nil && info.Mode()&os.ModeCharDevice != 0
}
