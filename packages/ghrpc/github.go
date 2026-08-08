package main

import (
	"fmt"
	"os/exec"
	"strings"
)

// createGitHubRepo shells out to gh, which already holds the auth token.
func createGitHubRepo(cfg config, name, description, visibility string) error {
	args := []string{"repo", "create", cfg.githubUser + "/" + name, "--" + visibility}
	if description != "" {
		args = append(args, "--description", description)
	}

	cmd := exec.Command(ghBin, args...)
	var stderr strings.Builder
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		if msg := strings.TrimSpace(stderr.String()); msg != "" {
			return fmt.Errorf("%s", firstLines(msg, 3))
		}
		return err
	}
	return nil
}

func firstLines(s string, n int) string {
	lines := strings.Split(s, "\n")
	if len(lines) > n {
		lines = lines[:n]
	}
	return strings.Join(lines, "\n")
}
