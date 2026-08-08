package main

import (
	"path/filepath"
	"slices"
	"strings"

	"github.com/charmbracelet/lipgloss"
	"github.com/charmbracelet/lipgloss/tree"
)

// entry is one path the scaffold touched, and whether we wrote it or found it
// already there.
type entry struct {
	path    string
	skipped bool
}

// created returns the paths that were actually written, which are the only
// ones there is any point staging.
func created(entries []entry) []string {
	var paths []string
	for _, e := range entries {
		if !e.skipped {
			paths = append(paths, e.path)
		}
	}
	return paths
}

// fileTree renders what happened to the repo as a directory tree. Written
// files are bright, anything already present is dimmed, so a re-run reads as a
// report rather than a list.
func fileTree(root string, entries []entry) string {
	t := tree.Root(lipgloss.NewStyle().Bold(true).Render(root))
	branches := map[string]*tree.Tree{}

	slices.SortFunc(entries, func(a, b entry) int { return strings.Compare(a.path, b.path) })

	for _, e := range entries {
		parent, prefix := t, ""
		segments := strings.Split(e.path, "/")

		// Walk down, creating the branches this path needs on the way.
		for _, dir := range segments[:len(segments)-1] {
			prefix = filepath.Join(prefix, dir)
			branch, built := branches[prefix]
			if !built {
				branch = tree.Root(dirStyle.Render(dir + "/"))
				branches[prefix] = branch
				parent.Child(branch)
			}
			parent = branch
		}

		name := segments[len(segments)-1]
		parent.Child(fileStyle(name, e.skipped).Render(name))
	}

	return t.
		Enumerator(tree.RoundedEnumerator).
		EnumeratorStyle(dimStyle.PaddingRight(1)).
		String()
}

// fileStyle picks a colour by what the file is for: prose is worth reading,
// dotfiles and vendored text are plumbing, and anything we did not write
// recedes entirely.
func fileStyle(name string, skipped bool) lipgloss.Style {
	switch {
	case skipped, strings.HasPrefix(name, "."), strings.HasSuffix(name, ".txt"):
		return dimStyle
	case strings.HasSuffix(name, ".md"):
		return proseStyle
	}
	return lipgloss.NewStyle()
}
