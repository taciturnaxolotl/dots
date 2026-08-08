package main

import (
	"fmt"
	"os"
	"path/filepath"
	"slices"
	"time"

	"github.com/spf13/cobra"
)

// newTemplateCmd is the authoring loop: list what exists, and render one into
// a directory so a template can be iterated on without creating a repo.
func newTemplateCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "template",
		Short: "Inspect and preview the embedded templates",
	}
	cmd.AddCommand(newTemplateListCmd(), newTemplateRenderCmd())
	return cmd
}

func newTemplateListCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "list",
		Short: "List the templates and what they ask about",
		Args:  cobra.NoArgs,
		RunE: func(cmd *cobra.Command, _ []string) error {
			for _, scaffold := range scaffolds() {
				m := loadManifest(scaffold)

				sec := newSection("type", "licences", "files")
				fmt.Fprintln(cmd.OutOrStdout())
				sec.row(scaffold, m.Description)
				sec.row("type", m.Type)
				for _, slot := range m.Licence {
					sec.row("licence", fmt.Sprintf("%s: %s", slot.Key, listOr(slot.Options)))
				}
				sec.row("files", fmt.Sprint(len(scaffoldFiles(scaffold))))
			}
			return nil
		},
	}
}

func newTemplateRenderCmd() *cobra.Command {
	var licence string

	cmd := &cobra.Command{
		Use:   "render NAME DIR",
		Short: "Render a template into a directory, without touching git or any forge",
		Long: `Render a template into a directory so it can be reviewed before it is used for real.

Nothing is created, committed or pushed: this writes files and prints the same tree a run would.`,
		Args: cobra.ExactArgs(2),
		RunE: func(cmd *cobra.Command, args []string) error {
			scaffold, dir := args[0], args[1]
			if !slices.Contains(scaffolds(), scaffold) {
				return fmt.Errorf("no such template %q (have %s)", scaffold, listOr(scaffolds()))
			}
			if err := os.MkdirAll(dir, 0o755); err != nil {
				return err
			}
			here, err := os.Getwd()
			if err != nil {
				return err
			}
			if err := os.Chdir(dir); err != nil {
				return err
			}
			defer os.Chdir(here)

			name := filepath.Base(filepath.Clean(dir))
			opts := &options{
				name:       name,
				scaffold:   scaffold,
				licenses:   map[string]string{},
				splitFiles: true,
				visibility: "public",
			}
			// Preview the recommended licence for each slot unless told otherwise.
			for _, slot := range slotsFor(scaffold) {
				if licence != "" && slices.Contains(slot.Options, licence) {
					opts.licenses[slot.Key] = licence
				} else if len(slot.Options) > 0 {
					opts.licenses[slot.Key] = slot.Options[0]
				}
			}

			touched := applyTemplates(opts, previewData(name))
			fmt.Fprintln(cmd.OutOrStdout(), fileTree(name, touched))
			return nil
		},
	}
	cmd.Flags().StringVarP(&licence, "license", "l", "", "preview with this licence where a slot offers it")
	return cmd
}

// previewData is a filled-in context so a preview shows every field populated.
func previewData(name string) templateData {
	return templateData{
		Name:           name,
		Description:    "a preview of the " + name + " template",
		Year:           time.Now().Year(),
		Owner:          defaultOwner,
		OwnerURL:       defaultOwnerURL,
		GitHubUser:     defaultGitHubUser,
		TangledDomain:  defaultDomain,
		Branch:         defaultBranch,
		Canonical:      fmt.Sprintf("https://tangled.org/%s/%s", defaultDomain, name),
		CanonicalForge: "tangled",
		Forges:         []string{"tangled", "github"},
	}
}
