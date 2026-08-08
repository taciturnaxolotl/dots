package main

import (
	"os"
	"strings"
	"testing"

	"github.com/spf13/pflag"
)

// TestManPageCoversEveryFlag keeps the hand-written man page honest. It is
// hand-written because a generated one cannot describe templates or licence
// slots, but that means nothing stops it drifting behind the command tree
// except this.
func TestManPageCoversEveryFlag(t *testing.T) {
	page, err := os.ReadFile("ghrpc.1.md")
	if err != nil {
		t.Fatal(err)
	}
	text := string(page)

	newRootCmd().Flags().VisitAll(func(f *pflag.Flag) {
		if !strings.Contains(text, "**--"+f.Name+"**") {
			t.Errorf("--%s is not documented in ghrpc.1.md", f.Name)
		}
		if f.Shorthand != "" && !strings.Contains(text, "**-"+f.Shorthand+"**") {
			t.Errorf("-%s (--%s) is not documented in ghrpc.1.md", f.Shorthand, f.Name)
		}
	})

	// Subcommands are the part a generated page would at least have listed.
	for _, cmd := range newRootCmd().Commands() {
		if cmd.Name() == "help" {
			continue
		}
		if !strings.Contains(text, "**"+cmd.Name()+"**") {
			t.Errorf("subcommand %q is not documented in ghrpc.1.md", cmd.Name())
		}
	}

	// Every template ships a description in the page, since that is where
	// someone looks to find out what they can scaffold.
	for _, scaffold := range scaffolds() {
		if !strings.Contains(text, "**"+scaffold+"**") {
			t.Errorf("template %q is not documented in ghrpc.1.md", scaffold)
		}
	}
}
