package main

import (
	"io/fs"
	"path/filepath"
	"slices"
	"strings"
	"testing"
)

// sampleData is a fully populated context, so executing a template here
// exercises every field a real run would supply.
func sampleData() templateData {
	return templateData{
		Name:           "sample",
		Description:    "a sample repo",
		Year:           2026,
		Owner:          defaultOwner,
		OwnerURL:       defaultOwnerURL,
		GitHubUser:     defaultGitHubUser,
		TangledDomain:  defaultDomain,
		Branch:         defaultBranch,
		Canonical:      "https://tangled.org/example/sample",
		CanonicalForge: "tangled",
		Forges:         []string{"tangled", "github"},
		Root:           "",
		Licenses:       map[string]licenseInfo{},
	}
}

// TestTemplatesAreWellFormed is the guard that keeps an authoring typo from
// reaching a repo. Templates are embedded, so everything it checks is knowable
// at build time, and `nix build` runs this.
func TestTemplatesAreWellFormed(t *testing.T) {
	known := licenses()

	for _, scaffold := range scaffolds() {
		m := loadManifest(scaffold) // panics on missing or malformed TOML

		if m.Type == "" {
			t.Errorf("%s: template.toml has no type", scaffold)
		}
		seen := map[string]bool{}

		for _, slot := range m.Licence {
			switch {
			case slot.Key == "":
				t.Errorf("%s: a licence slot has no key", scaffold)
			case seen[slot.Key]:
				t.Errorf("%s: duplicate licence slot %q", scaffold, slot.Key)
			}
			seen[slot.Key] = true

			if len(slot.Options) == 0 {
				t.Errorf("%s/%s: no licence options", scaffold, slot.Key)
			}
			for _, id := range slot.Options {
				if !slices.Contains(known, id) {
					t.Errorf("%s/%s: unknown licence %q", scaffold, slot.Key, id)
				}
			}
			if slot.Path != "" {
				if filepath.IsAbs(slot.Path) || strings.Contains(slot.Path, "..") {
					t.Errorf("%s/%s: path %q escapes the repo", scaffold, slot.Key, slot.Path)
				}
			}
			// Several slots render into one LICENSE.md, which needs headings.
			if len(m.Licence) > 1 && (slot.Section == "" || slot.Covers == "") {
				t.Errorf("%s/%s: multi-slot templates need section and covers", scaffold, slot.Key)
			}
		}
	}
}

// TestNoJunkInTemplates guards the embed directive, which takes everything
// under templates/ including whatever the OS leaves lying around.
func TestNoJunkInTemplates(t *testing.T) {
	err := fs.WalkDir(templateFS, templateRoot, func(path string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() {
			return err
		}
		if isJunk(path) {
			t.Errorf("%s is embedded but should never ship", path)
		}
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
}

// TestLicenceRegistryIsComplete checks every licence can actually be written.
func TestLicenceRegistryIsComplete(t *testing.T) {
	for _, id := range licenses() {
		info := licenseRegistry[id]
		if info.Name == "" || info.Badge == "" {
			t.Errorf("%s: needs a name and a badge", id)
		}
		if _, err := templateFS.ReadFile(filepath.Join(licenseDir, id+".md"+tmplSuffix)); err != nil {
			t.Errorf("%s: no body at %s.md%s", id, id, tmplSuffix)
		}
		if info.Text == "" {
			continue
		}
		if _, err := templateFS.ReadFile(filepath.Join(licenseDir, "texts", info.Text)); err != nil {
			t.Errorf("%s: declares text %q which is not in texts/", id, info.Text)
		}
	}
}

// TestEveryTemplateRenders parses and executes every .tmpl in the tree. A
// template that references a field the context does not have fails here rather
// than half way through writing someone's repo.
func TestEveryTemplateRenders(t *testing.T) {
	data := sampleData()
	for _, id := range licenses() {
		data.Licenses[id] = licenseRegistry[id]
	}
	// Slot keys are what templates actually look up.
	for _, scaffold := range scaffolds() {
		for _, slot := range slotsFor(scaffold) {
			data.Licenses[slot.Key] = licenseRegistry[slot.Options[0]]
		}
	}

	err := fs.WalkDir(templateFS, templateRoot, func(path string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() || !strings.HasSuffix(path, tmplSuffix) {
			return err
		}
		if _, err := renderFile(path, data); err != nil {
			t.Errorf("%s: %v", path, err)
		}
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
}

// TestEveryLicenceComposes renders LICENSE.md for every scaffold against every
// licence its slots offer, which is where a bad slot/licence pairing shows up.
func TestEveryLicenceComposes(t *testing.T) {
	for _, scaffold := range scaffolds() {
		slots := slotsFor(scaffold)
		if len(slots) == 0 {
			continue
		}
		for _, slot := range slots {
			for _, id := range slot.Options {
				chosen := map[string]string{}
				for _, s := range slots {
					chosen[s.Key] = s.Options[0]
				}
				chosen[slot.Key] = id

				if _, err := composeLicense(slots, chosen, sampleData()); err != nil {
					t.Errorf("%s with %s=%s: %v", scaffold, slot.Key, id, err)
				}
			}
		}
	}
}
