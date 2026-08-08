package main

import (
	"embed"
	"fmt"
	"io/fs"
	"math"
	"os"
	"path/filepath"
	"slices"
	"sort"
	"strings"
	"text/template"

	"github.com/BurntSushi/toml"
)

// all: keeps dotfiles (.gitignore, .gitkeep) in the embedded tree.
//
//go:embed all:templates
var templateFS embed.FS

// osJunk is never intentional in a template. The embed directive takes
// everything under templates/, including whatever Finder leaves behind.
var osJunk = []string{".DS_Store", "Thumbs.db"}

func isJunk(path string) bool {
	return slices.Contains(osJunk, filepath.Base(path))
}

const (
	templateRoot = "templates"
	licenseDir   = "templates/licenses"
	manifestName = "template.toml"
	tmplSuffix   = ".tmpl"
)

// manifest is the template.toml at the root of a scaffold. It groups scaffolds
// by project type and declares the licensing questions to ask.
type manifest struct {
	Type string `toml:"type"`
	// Order sorts the project-type picker; lower comes first. Templates that
	// omit it sort last, alphabetically.
	Order       int           `toml:"order"`
	Description string        `toml:"description"`
	Licence     []licenseSlot `toml:"licence"`
}

// templateData is what every .tmpl file in a scaffold gets rendered against.
type templateData struct {
	Name          string
	Description   string
	Year          int
	Owner         string
	OwnerURL      string
	GitHubUser    string
	TangledDomain string
	Branch        string
	// Canonical is the repo's home, and CanonicalForge names it. Forges lists
	// every forge it was published to.
	Canonical      string
	CanonicalForge string
	Forges         []string
	// Root walks back up to the repo root ("" at the top, "../" one level
	// down), for links in a file written into a subdirectory.
	Root string
	// Licenses holds the chosen licence per slot key, for templates that want
	// to name them (badges, headers).
	Licenses map[string]licenseInfo
}

// Lic looks up a chosen licence by slot key, for use as {{(.Lic "hardware").Badge}}.
func (d templateData) Lic(key string) licenseInfo { return d.Licenses[key] }

// scaffolds lists the available repo templates. Dropping a directory into
// templates/ is all it takes to add one.
func scaffolds() []string {
	entries, err := fs.ReadDir(templateFS, templateRoot)
	if err != nil {
		return nil
	}
	var names []string
	for _, e := range entries {
		if e.IsDir() && e.Name() != "licenses" {
			names = append(names, e.Name())
		}
	}
	sort.Strings(names)
	return names
}

// loadManifest reads a scaffold's template.toml.
//
// Templates are embedded, so a missing or malformed manifest is a build error
// rather than something to paper over at runtime: silently falling back would
// quietly relicense the project. The template test catches this first.
func loadManifest(scaffold string) manifest {
	raw, err := templateFS.ReadFile(filepath.Join(templateRoot, scaffold, manifestName))
	if err != nil {
		panic(fmt.Sprintf("template %s has no %s", scaffold, manifestName))
	}
	var m manifest
	if _, err := toml.Decode(string(raw), &m); err != nil {
		panic(fmt.Sprintf("template %s has a malformed %s: %v", scaffold, manifestName, err))
	}
	return m
}

// projectTypes lists the distinct project types across all scaffolds, ordered
// by each type's lowest declared order so the common case leads.
func projectTypes() []string {
	var types []string
	order := map[string]int{}
	for _, s := range scaffolds() {
		m := loadManifest(s)
		if !slices.Contains(types, m.Type) {
			types = append(types, m.Type)
			order[m.Type] = m.Order
		} else if m.Order != 0 && (order[m.Type] == 0 || m.Order < order[m.Type]) {
			order[m.Type] = m.Order
		}
	}
	sort.Slice(types, func(i, j int) bool {
		a, b := order[types[i]], order[types[j]]
		if a == 0 {
			a = math.MaxInt // unordered templates sort last
		}
		if b == 0 {
			b = math.MaxInt
		}
		if a != b {
			return a < b
		}
		return types[i] < types[j]
	})
	return types
}

func scaffoldsFor(projectType string) []string {
	var names []string
	for _, s := range scaffolds() {
		if loadManifest(s).Type == projectType {
			names = append(names, s)
		}
	}
	return names
}

// scaffoldFiles lists the paths a scaffold would write, relative to the repo.
func scaffoldFiles(scaffold string) []string {
	if scaffold == "" || scaffold == noScaffold {
		return nil
	}
	root := filepath.Join(templateRoot, scaffold)
	var paths []string
	_ = fs.WalkDir(templateFS, root, func(path string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() {
			return err
		}
		dest := strings.TrimSuffix(strings.TrimPrefix(path, root+"/"), tmplSuffix)
		if dest != manifestName && !isJunk(dest) {
			paths = append(paths, dest)
		}
		return nil
	})
	return paths
}

// writeScaffold renders a template tree into the current directory. Existing
// files are left alone, so it is safe to run over a repo that already has work
// in it. Returns what it wrote and what was already there.
func writeScaffold(scaffold string, data templateData) ([]entry, error) {
	root := filepath.Join(templateRoot, scaffold)
	var written []entry

	err := fs.WalkDir(templateFS, root, func(path string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() {
			return err
		}

		dest := strings.TrimSuffix(strings.TrimPrefix(path, root+"/"), tmplSuffix)
		if dest == manifestName || isJunk(dest) {
			return nil
		}
		if _, err := os.Stat(dest); err == nil {
			// Never clobber work that is already there, but say it was seen.
			written = append(written, entry{path: dest, skipped: true})
			return nil
		}
		if dir := filepath.Dir(dest); dir != "." {
			if err := os.MkdirAll(dir, 0o755); err != nil {
				return err
			}
		}

		content, err := renderFile(path, data)
		if err != nil {
			return err
		}
		if err := os.WriteFile(dest, content, 0o644); err != nil {
			return err
		}
		written = append(written, entry{path: dest})
		return nil
	})

	return written, err
}

func renderFile(path string, data templateData) ([]byte, error) {
	raw, err := templateFS.ReadFile(path)
	if err != nil {
		return nil, err
	}
	if !strings.HasSuffix(path, tmplSuffix) {
		return raw, nil
	}

	tmpl, err := template.New(filepath.Base(path)).Parse(string(raw))
	if err != nil {
		return nil, fmt.Errorf("%s: %w", path, err)
	}
	var out strings.Builder
	if err := tmpl.Execute(&out, data); err != nil {
		return nil, fmt.Errorf("%s: %w", path, err)
	}
	return []byte(out.String()), nil
}
