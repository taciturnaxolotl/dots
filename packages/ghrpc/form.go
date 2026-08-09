package main

import (
	"fmt"

	"charm.land/huh/v2"
	"charm.land/lipgloss/v2"
)

type options struct {
	name        string
	description string
	visibility  string
	projectType string
	scaffold    string
	licenses    map[string]string
	splitFiles  bool
	useGitHub   bool
	useTangled  bool
}

// given records which options came from the command line, so the form only
// asks about the rest.
type given struct {
	description bool
	visibility  bool
	target      bool
	scaffold    bool
	licenses    bool
	splitFiles  bool
	// licenceFlags are the raw -l values, resolved once the scaffold is known.
	licenceFlags []string
}

const (
	targetBoth    = "Both GitHub and Tangled"
	targetGitHub  = "GitHub only"
	targetTangled = "Tangled only"
	noScaffold    = "none"
)

// ask collects everything up front in one form, so the work that follows runs
// without stopping to prompt. Project type comes first and narrows the template
// behind it, which in turn decides which licences get asked about.
func ask(opts *options, set given) {
	target := targetBoth
	switch {
	case !opts.useTangled:
		target = targetGitHub
	case !opts.useGitHub:
		target = targetTangled
	}

	var fields []huh.Field

	if opts.name == "" {
		if inWorkTree() {
			opts.name = repoName()
		}
		fields = append(fields, huh.NewInput().
			Title("Repository name").
			Placeholder("my-repo").
			Validate(validateName).
			Value(&opts.name))
	}
	if !set.description {
		fields = append(fields, huh.NewInput().
			Title("Description").
			Placeholder("A cool project").
			Value(&opts.description))
	}
	if !set.visibility {
		fields = append(fields, selectField(huh.NewOptions("public", "private"), &opts.visibility).
			Title("Visibility"))
	}
	if !set.target {
		fields = append(fields, selectField(huh.NewOptions(targetBoth, targetGitHub, targetTangled), &target).
			Title("Create on"))
	}

	// An empty group panics inside huh, and every field here may have come
	// from a flag instead.
	var groups []*huh.Group
	if len(fields) > 0 {
		groups = append(groups, huh.NewGroup(fields...))
	}

	// Every picker below has a static option list and a hide rule, rather than
	// one picker whose options change. huh cannot measure a list it has not
	// built yet, and an OptionsFunc picker collapses to a single scrolling row.
	if !set.scaffold {
		groups = append(groups, huh.NewGroup(
			selectField(typeOptions(), &opts.projectType).Title("Project type"),
		))
		for _, projectType := range projectTypes() {
			list := scaffoldsFor(projectType)
			if len(list) < 2 {
				continue // the type's only layout needs no picking
			}
			groups = append(groups, huh.NewGroup(
				selectField(huh.NewOptions(list...), &opts.scaffold).Title("Template"),
			).WithHideFunc(func() bool { return opts.projectType != projectType }))
		}
	}

	// One licence question per slot, per template.
	answers := map[string]map[string]*string{}
	if !set.licenses {
		for _, scaffold := range scaffolds() {
			answers[scaffold] = map[string]*string{}
			for _, slot := range slotsFor(scaffold) {
				answer := new(string)
				answers[scaffold][slot.Key] = answer
				groups = append(groups, huh.NewGroup(
					selectField(licenseOptions(slot.Options), answer).Title(slot.Title()),
				).WithHideFunc(func() bool { return chosenScaffold(opts) != scaffold }))
			}
		}
	}

	if !set.splitFiles {
		groups = append(groups, huh.NewGroup(
			yesNo(
				"Write a LICENSE.md into each directory too?",
				"Root LICENSE.md stays authoritative; copies travel with the directory.",
				&opts.splitFiles,
			),
		).WithHideFunc(func() bool { return !splittable(chosenScaffold(opts)) }))
	}

	if len(groups) > 0 {
		if err := huh.NewForm(groups...).WithTheme(formTheme).Run(); err != nil {
			abort(err)
		}
	}

	opts.scaffold = chosenScaffold(opts)
	if opts.licenses == nil {
		opts.licenses = map[string]string{}
	}
	for _, slot := range slotsFor(opts.scaffold) {
		if answer := answers[opts.scaffold][slot.Key]; answer != nil && *answer != "" {
			if _, alreadySet := opts.licenses[slot.Key]; !alreadySet {
				opts.licenses[slot.Key] = *answer
			}
		}
	}

	switch target {
	case targetGitHub:
		opts.useTangled = false
	case targetTangled:
		opts.useGitHub = false
	}
}

// typeOptions lists the project types, plus the escape hatch.
func typeOptions() []huh.Option[string] {
	return huh.NewOptions(append(projectTypes(), noScaffold)...)
}

// licenseOptions pairs each licence with its one-line gloss, dimmed so the
// name still reads first.
func licenseOptions(ids []string) []huh.Option[string] {
	width := 0
	for _, id := range ids {
		width = max(width, lipgloss.Width(id))
	}
	options := make([]huh.Option[string], 0, len(ids))
	for _, id := range ids {
		label := id
		if gloss := licenseRegistry[id].Description; gloss != "" {
			label = fmt.Sprintf("%-*s  %s", width, id, dimStyle.Render(gloss))
		}
		options = append(options, huh.NewOption(label, id))
	}
	return options
}

// splittable reports whether a scaffold has slots that name their own file.
func splittable(scaffold string) bool {
	for _, slot := range slotsFor(scaffold) {
		if slot.Path != "" {
			return true
		}
	}
	return false
}

// slotFor returns the named slot of a scaffold, or a zero slot when it has none.
func slotFor(scaffold, key string) licenseSlot {
	for _, slot := range slotsFor(scaffold) {
		if slot.Key == key {
			return slot
		}
	}
	return licenseSlot{}
}

// chosenScaffold resolves the template while the form is still running: a
// project type with a single layout never shows the template question, but the
// licence steps behind it still need to know what was picked.
func chosenScaffold(opts *options) string {
	if opts.scaffold != "" {
		return opts.scaffold
	}
	if only := scaffoldsFor(opts.projectType); len(only) == 1 {
		return only[0]
	}
	return noScaffold
}

func validateName(name string) error {
	if name == "" {
		return fmt.Errorf("repository name is required")
	}
	if !validName.MatchString(name) {
		return fmt.Errorf("use only alphanumeric, dots, hyphens, and underscores")
	}
	return nil
}
