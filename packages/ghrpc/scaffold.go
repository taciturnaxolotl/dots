package main

import (
	"os"
	"strings"
)

// licenceRow is one line of the licence summary: the slots it covers and the
// licence they landed on.
type licenceRow struct {
	slots string // "hardware", or "firmware/docs" when they agree
	id    string // SPDX-style identifier
}

// licenceRows folds neighbouring slots that chose the same licence into one
// line, so a repo licensed uniformly does not repeat itself.
func licenceRows(opts *options) []licenceRow {
	var rows []licenceRow
	slots := slotsFor(opts.scaffold)
	for i := 0; i < len(slots); {
		id := opts.licenses[slots[i].Key]
		keys := []string{slots[i].Key}

		j := i + 1
		for ; j < len(slots) && opts.licenses[slots[j].Key] == id; j++ {
			keys = append(keys, slots[j].Key)
		}
		rows = append(rows, licenceRow{slots: strings.Join(keys, "/"), id: licenseRegistry[id].ID})
		i = j
	}
	return rows
}

// chosenLicences is the licence per slot, for templates that name them.
func chosenLicences(opts *options) map[string]licenseInfo {
	chosen := map[string]licenseInfo{}
	for _, slot := range slotsFor(opts.scaffold) {
		chosen[slot.Key] = licenseRegistry[opts.licenses[slot.Key]]
	}
	return chosen
}

// resolveLicences settles the licence for every slot the chosen scaffold has.
//
// This runs after the scaffold is known, which is the whole point: a bare
// "-l MIT" names the first slot, but which slot that is depends on a template
// the user may not have picked until the form ran.
func resolveLicences(opts *options, set given) {
	if opts.licenses == nil {
		opts.licenses = map[string]string{}
	}
	slots := slotsFor(opts.scaffold)

	for _, value := range set.licenceFlags {
		key, id, qualified := strings.Cut(value, "=")
		if !qualified {
			if len(slots) > 0 {
				opts.licenses[slots[0].Key] = value
			}
			continue
		}
		opts.licenses[key] = id
	}

	// Anything still unset falls back to the slot's first, recommended licence.
	for _, slot := range slots {
		if opts.licenses[slot.Key] == "" && len(slot.Options) > 0 {
			opts.licenses[slot.Key] = slot.Options[0]
		}
	}
}

// applyTemplates writes the licence first so the README badge can name it. It
// returns every path it touched, marking the ones already present.
func applyTemplates(opts *options, data templateData) []entry {
	if opts.scaffold == "" || opts.scaffold == noScaffold {
		return nil
	}

	var touched []entry
	slots := slotsFor(opts.scaffold)
	licences := newSection("LICENSE.md", opts.scaffold)

	if len(slots) > 0 {
		if fileExists("LICENSE.md") {
			touched = append(touched, entry{path: "LICENSE.md", skipped: true})
		} else if content, err := composeLicense(slots, opts.licenses, data); err != nil {
			licences.fail("LICENSE.md", "could not render: "+err.Error())
		} else if err := os.WriteFile("LICENSE.md", []byte(content), 0o644); err != nil {
			licences.fail("LICENSE.md", "could not write: "+err.Error())
		} else {
			touched = append(touched, entry{path: "LICENSE.md"})
		}
	}
	if opts.splitFiles {
		touched = append(touched, writeSlotLicenses(slots, opts.licenses, data)...)
	}
	touched = append(touched, writeLicenseTexts(opts.licenses)...)

	written, err := writeScaffold(opts.scaffold, data)
	if err != nil {
		licences.fail(opts.scaffold, "could not apply the template: "+err.Error())
	}
	return append(touched, written...)
}
