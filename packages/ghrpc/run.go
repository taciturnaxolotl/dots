package main

import (
	"fmt"

	"charm.land/lipgloss/v2"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// runner carries one invocation: what was asked for, where it is going, and
// the two columns the output is printed in.
type runner struct {
	cfg         config
	opts        *options
	forges      []forge
	head        *section // what the repo is and where it lives
	work        *section // what was done to it locally
	interactive bool
	// topUp is set when we are adding to a repo that already has remotes, so
	// nothing is created and no remote is retargeted without asking.
	topUp bool
}

func run(cfg config, opts *options, set given) error {
	interactive := interactiveSession()
	if interactive {
		ask(opts, set)
	} else {
		applyNonInteractiveDefaults(opts)
	}
	// Licences resolve against the scaffold, which is only known now: the -l
	// flag may have been given before -T, or without one at all.
	resolveLicences(opts, set)

	if err := validateName(opts.name); err != nil {
		return fmt.Errorf("invalid repository name: %w", err)
	}
	if err := enterRepoDir(opts.name); err != nil {
		return err
	}

	list := forges(cfg, opts)
	r := &runner{
		cfg:         cfg,
		opts:        opts,
		forges:      list,
		head:        newSection(append(labels(list), headLabels(opts)...)...),
		work:        newSection(append(remotes(list), "init", "commit")...),
		interactive: interactive,
	}

	proceed, err := r.inspect()
	if err != nil || !proceed {
		return err
	}

	r.describe()
	fmt.Println()

	if err := r.initRepo(); err != nil {
		return err
	}
	r.wireRemotes()

	touched := r.writeFiles()
	r.publish(created(touched))
	if len(touched) > 0 {
		fmt.Println()
		lipgloss.Println(fileTree(opts.name, touched))
	}

	reportDir()
	return nil
}

// inspect looks at what is already here. An existing repo with remotes means
// we are topping up rather than creating, which needs the user's blessing.
func (r *runner) inspect() (proceed bool, err error) {
	if !inWorkTree() {
		return true, nil
	}
	existing := remoteLines()
	if len(existing) == 0 {
		return true, nil
	}

	found := newSection("remotes")
	found.fail("remotes", "this repo is already configured")
	for _, remote := range existing {
		found.row(remote.name, dim(remote.url))
	}
	fmt.Println()

	missing := r.missingFiles()
	switch {
	case len(missing) > 0:
		newSection("missing").row("missing", strings.Join(missing, ", "))
		fmt.Println()
		if r.interactive && !confirm("Continue and add missing files?") {
			return false, nil
		}
	case !r.interactive:
		return false, fmt.Errorf("repository already fully configured")
	case !confirm("Reconfigure remotes?"):
		return false, nil
	}

	r.topUp = true
	return true, nil
}

// describe prints what the repo is, creating each forge as its row is reached
// so the line carries either the URL or the reason there isn't one.
func (r *runner) describe() {
	r.head.row("name", r.opts.name)
	if r.opts.description != "" {
		r.head.row("description", r.opts.description)
	}

	for _, f := range r.forges {
		switch reason := r.blockedReason(f); {
		case reason != "":
			r.head.fail(f.name, reason)
		case r.topUp:
			r.head.row(f.name, link(f.url))
		default:
			var err error
			r.head.step("creating on "+f.name, func() { err = f.create() })
			if err != nil {
				r.head.fail(f.name, err.Error())
			} else {
				r.head.row(f.name, link(f.url))
			}
		}
	}

	for _, licence := range licenceRows(r.opts) {
		r.head.row(licence.slots, licence.id)
	}
	if len(r.forges) > 0 {
		r.head.row("visibility", r.opts.visibility)
	}
}

func (r *runner) blockedReason(f forge) string {
	if r.topUp || f.blocked == nil {
		return ""
	}
	return f.blocked()
}

func (r *runner) initRepo() error {
	if inWorkTree() {
		return nil
	}
	if r.interactive && dirHasFiles(".") && !confirm("Directory has files but no git repo. Initialize?") {
		return fmt.Errorf("git repository required")
	}
	if err := gitQuiet("init", "-b", r.cfg.branch); err != nil {
		return fmt.Errorf("failed to initialize git repository: %w", err)
	}
	r.work.row("init", r.cfg.branch)
	return nil
}

func (r *runner) wireRemotes() {
	if r.topUp {
		return
	}
	for _, f := range r.forges {
		setRemote(r.work, f.remote, f.ssh)
		if f.remote == "origin" {
			_ = gitQuiet("config", "branch."+r.cfg.branch+".remote", "origin")
		}
	}
}

func (r *runner) writeFiles() []entry {
	return applyTemplates(r.opts, templateData{
		Name:           r.opts.name,
		Description:    r.opts.description,
		Year:           time.Now().Year(),
		Owner:          defaultOwner,
		OwnerURL:       defaultOwnerURL,
		GitHubUser:     r.cfg.githubUser,
		TangledDomain:  r.cfg.domain,
		Branch:         r.cfg.branch,
		Canonical:      r.canonical().url,
		CanonicalForge: r.canonical().name,
		Forges:         labels(r.forges),
		Licenses:       chosenLicences(r.opts),
	})
}

// canonical is where the templates point readers, and what the CERN licences
// quote as the Source Location: the first forge is the canonical one. With no
// forge at all the tangled URL is still the address this repo would have, so
// badges and licence notices stay meaningful.
func (r *runner) canonical() forge {
	if len(r.forges) > 0 {
		return r.forges[0]
	}
	return forge{
		name: "tangled",
		url:  fmt.Sprintf("https://tangled.org/%s/%s", r.cfg.domain, r.opts.name),
	}
}

// publish commits what was written and pushes it to every remote. The push
// spinners sit with the remote rows above, so this runs before the tree.
func (r *runner) publish(paths []string) {
	if len(paths) == 0 {
		return
	}
	if err := gitQuiet(append([]string{"add", "--"}, paths...)...); err != nil {
		r.work.fail("commit", "could not stage the new files")
		return
	}
	if err := gitQuiet(append([]string{"commit", "-m", "Add project templates", "--"}, paths...)...); err != nil {
		return
	}

	for _, f := range r.forges {
		if !hasRemote(f.remote) {
			continue
		}
		// origin gets -u so the branch tracks it; any secondary remote gets a
		// plain push so it can never steal the upstream.
		args := []string{"push"}
		if f.remote == "origin" {
			args = append(args, "-u")
		}
		args = append(args, f.remote, r.cfg.branch)

		var err error
		r.work.step("pushing to "+f.remote, func() { err = gitQuiet(args...) })
		if err != nil {
			r.work.fail(f.remote, "could not push")
		}
	}
}

// missingFiles reports which of the scaffold's top-level files this repo does
// not have yet, so a top-up run can say what it would add.
func (r *runner) missingFiles() []string {
	var missing []string
	for _, path := range scaffoldFiles(r.opts.scaffold) {
		if !strings.Contains(path, "/") && !fileExists(path) {
			missing = append(missing, path)
		}
	}
	return missing
}

// headLabels are the fixed rows of the head section, beside the forge names.
func headLabels(opts *options) []string {
	labels := []string{"name", "description", "visibility"}
	for _, licence := range licenceRows(opts) {
		labels = append(labels, licence.slots)
	}
	return labels
}

// enterRepoDir moves into ./NAME unless we are already inside a repo of that name.
func enterRepoDir(name string) error {
	if inWorkTree() && filepath.Base(repoRoot()) == name {
		return nil
	}
	if err := os.MkdirAll(name, 0o755); err != nil {
		return fmt.Errorf("could not create %s: %w", name, err)
	}
	if err := os.Chdir(name); err != nil {
		return fmt.Errorf("could not enter %s: %w", name, err)
	}
	return nil
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
