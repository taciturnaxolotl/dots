package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

// licenseInfo is the registry entry for one license id.
type licenseInfo struct {
	ID   string `json:"-"`
	Name string `json:"name"`
	// Description is the one-line gloss shown beside the name in the picker.
	Description string `json:"description"`
	Badge       string `json:"badge"`
	// Text is the full licence text to ship alongside LICENSE.md, for licences
	// whose terms are not canonically hosted (the CERN OHL family).
	Text string `json:"text"`
}

// licenseSlot is one licensing decision a template asks for: hardware,
// firmware and documentation are licensed separately in an open hardware repo.
type licenseSlot struct {
	Key string `json:"key"`
	// Section names what the slot covers, in title case: "Hardware".
	Section string `json:"section"`
	// Covers is the noun phrase listed in the LICENSE.md summary.
	Covers string `json:"covers"`
	// Path is where a standalone copy of this slot's licence goes when the
	// repo is split, so the directory carries its own terms if it travels.
	Path     string   `json:"path"`
	Licenses []string `json:"licenses"`
}

// Title is what the picker asks.
func (s licenseSlot) Title() string {
	if s.Section == "" {
		return "Licence"
	}
	return s.Section + " licence"
}

var licenseRegistry = func() map[string]licenseInfo {
	raw, err := templateFS.ReadFile(filepath.Join(licenseDir, "licenses.json"))
	if err != nil {
		return nil
	}
	var registry map[string]licenseInfo
	if err := json.Unmarshal(raw, &registry); err != nil {
		return nil
	}
	for id, info := range registry {
		info.ID = id
		registry[id] = info
	}
	return registry
}()

func licenses() []string {
	names := make([]string, 0, len(licenseRegistry))
	for id := range licenseRegistry {
		names = append(names, id)
	}
	sort.Strings(names)
	return names
}

// slotsFor returns the licensing questions a scaffold asks. An empty result
// means the scaffold needs no LICENSE.md written for it.
func slotsFor(scaffold string) []licenseSlot {
	if scaffold == "" || scaffold == noScaffold {
		return nil
	}
	return loadManifest(scaffold).LicenseSlots
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
func writeSlotLicenses(slots []licenseSlot, chosen map[string]string, data templateData) []string {
	var written []string
	for _, slot := range slots {
		if slot.Path == "" || fileExists(slot.Path) {
			continue
		}
		info := licenseRegistry[chosen[slot.Key]]

		// Links inside the body point at the root of the repo.
		nested := data
		nested.RootPrefix = strings.Repeat("../", strings.Count(slot.Path, "/"))
		body, err := licenseBody(info.ID, nested)
		if err != nil {
			continue
		}

		if err := os.MkdirAll(filepath.Dir(slot.Path), 0o755); err != nil {
			continue
		}
		content := fmt.Sprintf("# %s - %s\n\n%s", slot.Section, info.Name, body)
		if os.WriteFile(slot.Path, []byte(content), 0o644) == nil {
			written = append(written, slot.Path)
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
func writeLicenseTexts(chosen map[string]string) []string {
	var written []string
	for _, id := range chosen {
		info := licenseRegistry[id]
		if info.Text == "" || fileExists(info.Text) {
			continue
		}
		raw, err := templateFS.ReadFile(filepath.Join(licenseDir, "texts", info.Text))
		if err != nil {
			continue
		}
		if os.WriteFile(info.Text, raw, 0o644) == nil {
			written = append(written, info.Text)
		}
	}
	sort.Strings(written)
	return written
}
