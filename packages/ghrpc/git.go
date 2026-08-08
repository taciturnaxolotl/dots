package main

import (
	"os"
	"os/exec"
	"strings"
)

func git(args ...string) error {
	cmd := exec.Command(gitBin, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

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

func repoRoot() string {
	out, _ := gitOut("rev-parse", "--show-toplevel")
	return out
}

func hasRemote(name string) bool {
	_, err := gitOut("remote", "get-url", name)
	return err == nil
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
func setRemote(name, url string) {
	switch {
	case !hasRemote(name):
		if err := gitQuiet("remote", "add", name, url); err == nil {
			row(name, "%s", url)
		}
	case remoteURL(name) == url:
		rowDim(name, "%s", url)
	default:
		if err := gitQuiet("remote", "set-url", name, url); err == nil {
			row(name, "%s", url)
		}
	}
}
