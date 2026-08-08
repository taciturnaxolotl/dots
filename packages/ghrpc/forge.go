package main

import "fmt"

// A forge is somewhere a repo gets published. Everything that used to be a
// tangled-or-github fork lives here instead: the row label, the browser URL,
// the git remote, and how to create the repo. Adding a third forge is a
// constructor and a flag, not an edit in six places.
type forge struct {
	name   string // row label, also the browser-facing name
	url    string // where a human goes to read the repo
	remote string // git remote name
	ssh    string // git remote URL
	// blocked reports why this forge cannot be used, if it cannot.
	blocked func() string
	create  func() error
}

// forges lists the forges this run publishes to, in display order.
//
// Remote layout: origin is the knot when tangled is in play, github rides
// alongside; a GitHub-only repo gets github as origin so the branch still has
// an upstream.
func forges(cfg config, opts *options) []forge {
	var list []forge

	if opts.useTangled {
		list = append(list, forge{
			name:   "tangled",
			url:    fmt.Sprintf("https://tangled.org/%s/%s", cfg.domain, opts.name),
			remote: "origin",
			ssh:    fmt.Sprintf("git@%s:%s/%s", cfg.knotHost, cfg.plcID, opts.name),
			blocked: func() string {
				if !fileExists(cfg.credentialsFile) {
					return "no atproto credentials at " + cfg.credentialsFile
				}
				return ""
			},
			create: func() error { return createTangledRepo(cfg, opts.name, opts.description) },
		})
	}

	if opts.useGitHub {
		remote := "origin"
		if opts.useTangled {
			remote = "github"
		}
		list = append(list, forge{
			name:   "github",
			url:    fmt.Sprintf("https://github.com/%s/%s", cfg.githubUser, opts.name),
			remote: remote,
			ssh:    fmt.Sprintf("git@github.com:%s/%s.git", cfg.githubUser, opts.name),
			create: func() error {
				return createGitHubRepo(cfg, opts.name, opts.description, opts.visibility)
			},
		})
	}

	return list
}

// labels returns the row labels a forge list will print, for sizing a column.
func labels(list []forge) []string {
	names := make([]string, 0, len(list))
	for _, f := range list {
		names = append(names, f.name)
	}
	return names
}

// remotes returns the git remote names, which are not always the forge names.
func remotes(list []forge) []string {
	names := make([]string, 0, len(list))
	for _, f := range list {
		names = append(names, f.remote)
	}
	return names
}
