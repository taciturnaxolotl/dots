package main

import (
	"os/exec"
	"path/filepath"
	"strings"
)

// gitQuiet runs git with its output discarded, the way `2>/dev/null` did.
func gitQuiet(args ...string) error {
	return exec.Command(gitBin, args...).Run()
}

func gitOut(args ...string) (string, error) {
	out, err := exec.Command(gitBin, args...).Output()
	return strings.TrimSpace(string(out)), err
}

func inWorkTree() bool {
	out, err := gitOut("rev-parse", "--is-inside-work-tree")
	return err == nil && out == "true"
}

// repoName is the directory name of the enclosing repo.
func repoName() string { return filepath.Base(repoRoot()) }

func repoRoot() string {
	out, _ := gitOut("rev-parse", "--show-toplevel")
	return out
}

func hasRemote(name string) bool {
	_, err := gitOut("remote", "get-url", name)
	return err == nil
}

// pushBranch pushes branch to remote; origin gets -u so a secondary remote never steals the upstream.
func pushBranch(remote, branch string) error {
	args := []string{"push"}
	if remote == "origin" {
		args = append(args, "-u")
	}
	err := gitQuiet(append(args, remote, branch)...)
	if err != nil && remoteHasHead(remote, branch) {
		return nil // the knot mirror got there first
	}
	return err
}

func remoteHasHead(remote, branch string) bool {
	head, err := gitOut("rev-parse", "HEAD")
	if err != nil {
		return false
	}
	out, err := gitOut("ls-remote", remote, "refs/heads/"+branch)
	return err == nil && strings.HasPrefix(out, head+"\t")
}

func remoteURL(name string) string {
	out, _ := gitOut("remote", "get-url", name)
	return out
}

// remote is one configured remote, for reporting.
type remote struct{ name, url string }

// remoteLines lists the repo's remotes as name/url pairs.
func remoteLines() []remote {
	out, err := gitOut("remote")
	if err != nil || out == "" {
		return nil
	}
	var remotes []remote
	for _, name := range strings.Fields(out) {
		remotes = append(remotes, remote{name, remoteURL(name)})
	}
	return remotes
}

// setRemote adds or retargets a remote, dimming the line when it was already
// pointing where we wanted it.
func setRemote(sec *section, name, url string) {
	switch {
	case !hasRemote(name):
		if err := gitQuiet("remote", "add", name, url); err == nil {
			sec.row(name, url)
		}
	case remoteURL(name) == url:
		sec.row(name, dim(url))
	default:
		if err := gitQuiet("remote", "set-url", name, url); err == nil {
			sec.row(name, url)
		}
	}
}
