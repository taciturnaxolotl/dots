package main

import (
	"os"
	"strings"
	"testing"

	"github.com/spf13/pflag"
)

// TestManPageCoversEveryFlag keeps the hand-written man page honest. It is
// hand-written because a generated one cannot describe bore.toml, but that
// means nothing stops it drifting behind the flags except this.
func TestManPageCoversEveryFlag(t *testing.T) {
	page, err := os.ReadFile("bore.1.md")
	if err != nil {
		t.Fatal(err)
	}
	text := string(page)

	newRootCmd().Flags().VisitAll(func(f *pflag.Flag) {
		if !strings.Contains(text, "**--"+f.Name+"**") {
			t.Errorf("--%s is not documented in bore.1.md", f.Name)
		}
		if f.Shorthand != "" && !strings.Contains(text, "**-"+f.Shorthand+"**") {
			t.Errorf("-%s (--%s) is not documented in bore.1.md", f.Shorthand, f.Name)
		}
	})

	// The protocols are a promise to the user, so they belong in the page.
	for _, p := range protocols {
		if !strings.Contains(text, "**"+p+"**") {
			t.Errorf("protocol %q is not documented in bore.1.md", p)
		}
	}
}
