package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/BurntSushi/toml"
)

// licenseInfo is the registry entry for one licence id.
type licenseInfo struct {
	ID   string `toml:"id"`
	Name string `toml:"name"`
	// Description is the one-line gloss shown beside the name in the picker.
	Description string `toml:"description"`
	Badge       string `toml:"badge"`
	// Text is the full licence text to ship alongside LICENSE.md, for licences
	// whose terms are not canonically hosted (the CERN OHL family).
	Text string `toml:"text"`
}

// licenseSlot is one licensing decision a template asks for: hardware,
// firmware and documentation are licensed separately in an open hardware repo.
type licenseSlot struct {
	Key string `toml:"key"`
	// Section names what the slot covers, in title case: "Hardware".
	Section string `toml:"section"`
	// Covers is the noun phrase listed in the LICENSE.md summary.
	Covers string `toml:"covers"`
	// Path is where a standalone copy of this slot's licence goes when the
	// repo is split, so the directory carries its own terms if it travels.
	Path string `toml:"path"`
	// Options are the licences on offer, best default first.
	Options []string `toml:"options"`
}

// Title is what the picker asks.
func (s licenseSlot) Title() string {
	if s.Section == "" {
		return "Licence"
	}
	return s.Section + " licence"
}

const registryFile = "licenses.toml"

// The registry is embedded, so a malformed one is a build error rather than a
// runtime condition: loading panics, and the template test catches it first.
var licenseRegistry, licenseOrder = loadRegistry()

func loadRegistry() (map[string]licenseInfo, []string) {
	raw, err := templateFS.ReadFile(filepath.Join(licenseDir, registryFile))
	if err != nil {
		panic(fmt.Sprintf("embedded %s is missing: %v", registryFile, err))
	}
	var doc struct {
		Licence []licenseInfo `toml:"licence"`
	}
	if _, err := toml.Decode(string(raw), &doc); err != nil {
		panic(fmt.Sprintf("embedded %s is malformed: %v", registryFile, err))
	}

	registry := make(map[string]licenseInfo, len(doc.Licence))
	order := make([]string, 0, len(doc.Licence))
	for _, info := range doc.Licence {
		registry[info.ID] = info
		order = append(order, info.ID)
	}
	return registry, order
}

// licenses lists every licence id, in the order the registry declares them.
func licenses() []string { return licenseOrder }

// slotsFor returns the licensing questions a scaffold asks. An empty result
// means the scaffold needs no LICENSE.md written for it.
func slotsFor(scaffold string) []licenseSlot {
	if scaffold == "" || scaffold == noScaffold {
		return nil
	}
	return loadManifest(scaffold).Licence
}

// composeLicense renders LICENSE.md from the chosen licenses. A single slot
// gives the plain one-license file; several slots give a file with a summary
// and one section per slot.
func composeLicense(slots []licenseSlot, chosen map[string]string, data templateData) (string, error) {
	var out strings.Builder

	if len(slots) == 1 {
		info := licenseRegistry[chosen[slots[0].Key]]
		body, err := licenseBody(info.ID, data)
		if err != nil {
			return "", err
		}
		fmt.Fprintf(&out, "# %s\n\n%s", info.Name, body)
		return out.String(), nil
	}

	out.WriteString("# License\n\n")
	for _, slot := range slots {
		info := licenseRegistry[chosen[slot.Key]]
		fmt.Fprintf(&out, "- %s: **%s**\n", slot.Covers, info.Name)
	}
	out.WriteString("\n")
	for _, slot := range slots {
		info := licenseRegistry[chosen[slot.Key]]
		body, err := licenseBody(info.ID, data)
		if err != nil {
			return "", err
		}
		fmt.Fprintf(&out, "## %s - %s\n\n%s", slot.Section, info.Name, body)
	}
	return out.String(), nil
}

// licenseSummary names the chosen licences for the "Created LICENSE.md" line.
func licenseSummary(slots []licenseSlot, chosen map[string]string) string {
	var badges []string
	for _, slot := range slots {
		if info, found := licenseRegistry[chosen[slot.Key]]; found {
			badges = append(badges, strings.ReplaceAll(info.Badge, "+", " "))
		}
	}
	return strings.Join(badges, " + ")
}

// writeSlotLicenses drops a standalone LICENSE.md into each slot's directory.
// The root LICENSE.md stays authoritative; these are copies for anyone who
// takes a single directory away with them.
func writeSlotLicenses(slots []licenseSlot, chosen map[string]string, data templateData) []entry {
	var written []entry
	for _, slot := range slots {
		if slot.Path == "" {
			continue
		}
		if fileExists(slot.Path) {
			written = append(written, entry{path: slot.Path, skipped: true})
			continue
		}
		info := licenseRegistry[chosen[slot.Key]]

		// Links inside the body point at the root of the repo.
		nested := data
		nested.Root = strings.Repeat("../", strings.Count(slot.Path, "/"))
		body, err := licenseBody(info.ID, nested)
		if err != nil {
			continue
		}

		if err := os.MkdirAll(filepath.Dir(slot.Path), 0o755); err != nil {
			continue
		}
		content := fmt.Sprintf("# %s - %s\n\n%s", slot.Section, info.Name, body)
		if os.WriteFile(slot.Path, []byte(content), 0o644) == nil {
			written = append(written, entry{path: slot.Path})
		}
	}
	return written
}

func licenseBody(id string, data templateData) (string, error) {
	content, err := renderFile(filepath.Join(licenseDir, id+".md"+tmplSuffix), data)
	if err != nil {
		return "", err
	}
	return strings.TrimRight(string(content), "\n") + "\n\n", nil
}

// writeLicenseTexts drops the full text of any chosen licence that carries one,
// since the CERN OHL family expects a copy to travel with the design.
func writeLicenseTexts(chosen map[string]string) []entry {
	var written []entry
	for _, id := range chosen {
		info := licenseRegistry[id]
		if info.Text == "" {
			continue
		}
		if fileExists(info.Text) {
			written = append(written, entry{path: info.Text, skipped: true})
			continue
		}
		raw, err := templateFS.ReadFile(filepath.Join(licenseDir, "texts", info.Text))
		if err != nil {
			continue
		}
		if os.WriteFile(info.Text, raw, 0o644) == nil {
			written = append(written, entry{path: info.Text})
		}
	}
	return written
}
