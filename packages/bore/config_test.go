package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func inTempDir(t *testing.T, contents string) {
	t.Helper()
	dir := t.TempDir()
	if contents != "" {
		if err := os.WriteFile(filepath.Join(dir, ConfigFile), []byte(contents), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	here, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Chdir(dir); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { os.Chdir(here) })
}

// TestLoadAcceptsEverythingTheOldParserDid guards the switch from a bash
// line-regex parser to a real one: every shape the old CLI could read must
// still read the same way.
func TestLoadAcceptsEverythingTheOldParserDid(t *testing.T) {
	inTempDir(t, `# a comment
[myapp]
port = 8000

[api]
port = 3000
labels = ["dev", "api"]

[legacy]
port = 9000
label = "old-style"

[admin]
port = 3001
auth = true

[db]
port = 5432
protocol = "tcp"
`)

	cfg, err := LoadConfig()
	if err != nil {
		t.Fatal(err)
	}

	want := []string{"myapp", "api", "legacy", "admin", "db"}
	if got := cfg.Names(); strings.Join(got, ",") != strings.Join(want, ",") {
		t.Errorf("names = %v, want %v (file order matters)", got, want)
	}
	if got := cfg.Tunnels["api"].LabelString(); got != "dev,api" {
		t.Errorf("labels array: got %q", got)
	}
	// The old parser accepted a singular label=; files in the wild have it.
	if got := cfg.Tunnels["legacy"].LabelString(); got != "old-style" {
		t.Errorf("singular label: got %q", got)
	}
	if !cfg.Tunnels["admin"].Auth {
		t.Error("auth = true was not read")
	}
	if got := cfg.Tunnels["db"].Protocol; got != "tcp" {
		t.Errorf("protocol: got %q", got)
	}
	if got := cfg.Tunnels["myapp"].protocolOrDefault(); got != "http" {
		t.Errorf("default protocol: got %q", got)
	}
}

// TestLoadReadsWhatBashCouldNot covers valid TOML the line-regex parser
// mangled: inline comments, and no spaces around =.
func TestLoadReadsWhatBashCouldNot(t *testing.T) {
	inTempDir(t, `[commented]
port = 5000 # what this exposes
labels = ["a", "b"]

[tight]
port=1234
protocol="tcp"
`)

	cfg, err := LoadConfig()
	if err != nil {
		t.Fatal(err)
	}
	if got := cfg.Tunnels["commented"].Port; got != 5000 {
		t.Errorf("inline comment: port = %d", got)
	}
	if got := cfg.Tunnels["tight"].Protocol; got != "tcp" {
		t.Errorf("no spaces around =: protocol = %q", got)
	}
}

// TestSaveKeepsTheRestOfTheFile is the property that made splicing worth it:
// bore.toml is hand-edited and committed, so saving must not eat comments or
// reorder anything.
func TestSaveKeepsTheRestOfTheFile(t *testing.T) {
	original := `# my project's tunnels
# keep this comment

[myapp]
# the web frontend
port = 8000

[api]
port = 3000
`
	inTempDir(t, original)

	cfg, err := LoadConfig()
	if err != nil {
		t.Fatal(err)
	}
	if err := cfg.Save(&Tunnel{Name: "worker", Port: 4000, Labels: []string{"bg"}}); err != nil {
		t.Fatal(err)
	}

	raw, err := os.ReadFile(ConfigFile)
	if err != nil {
		t.Fatal(err)
	}
	got := string(raw)

	for _, keep := range []string{"# my project's tunnels", "# keep this comment", "# the web frontend", "[myapp]", "[api]"} {
		if !strings.Contains(got, keep) {
			t.Errorf("saving dropped %q:\n%s", keep, got)
		}
	}
	if !strings.Contains(got, "[worker]") {
		t.Errorf("new tunnel missing:\n%s", got)
	}
}

func TestSaveReplacesInPlace(t *testing.T) {
	inTempDir(t, `[myapp]
port = 8000
labels = ["old"]

[after]
port = 1111
`)

	cfg, err := LoadConfig()
	if err != nil {
		t.Fatal(err)
	}
	if err := cfg.Save(&Tunnel{Name: "myapp", Port: 9999, Protocol: "http", Auth: true}); err != nil {
		t.Fatal(err)
	}

	reloaded, err := LoadConfig()
	if err != nil {
		t.Fatal(err)
	}
	myapp := reloaded.Tunnels["myapp"]
	switch {
	case myapp.Port != 9999:
		t.Errorf("port not updated: %d", myapp.Port)
	case len(myapp.Labels) != 0:
		t.Errorf("stale labels survived: %v", myapp.Labels)
	case !myapp.Auth:
		t.Error("auth not written")
	case myapp.Protocol != "":
		t.Errorf("http is the default and should not be recorded, got %q", myapp.Protocol)
	}
	if reloaded.Tunnels["after"].Port != 1111 {
		t.Error("the table after the replaced one was damaged")
	}
}

// TestBuildConfigQuoting is why the frpc config is marshalled rather than
// concatenated: a label with a quote in it used to produce a broken file.
func TestBuildConfigQuoting(t *testing.T) {
	cfg := buildConfig(&Tunnel{
		Name:   "myapp",
		Port:   8000,
		Labels: []string{`we"ird`},
		Auth:   true,
	}, 8000, 0, false)

	path, err := writeConfig(cfg)
	if err != nil {
		t.Fatal(err)
	}
	defer os.Remove(path)

	raw, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	var round frpcConfig
	if err := decodeTOML(string(raw), &round); err != nil {
		t.Fatalf("the config we generate is not valid TOML: %v\n%s", err, raw)
	}
	if got := round.Proxies[0].Metadatas["labels"]; got != `we"ird` {
		t.Errorf("label round trip: got %q", got)
	}
	if got := round.Proxies[0].Metadatas["auth"]; got != "indiko" {
		t.Errorf("auth metadata: got %q, want indiko (this is what gates the tunnel)", got)
	}
	if got := round.Proxies[0].Subdomain; got != "myapp" {
		t.Errorf("http proxies need a subdomain, got %q", got)
	}
}

func TestValidate(t *testing.T) {
	for _, tc := range []struct {
		name    string
		tunnel  Tunnel
		wantErr bool
	}{
		{"ok", Tunnel{Name: "myapp", Port: 8000}, false},
		{"uppercase subdomain", Tunnel{Name: "MyApp", Port: 8000}, true},
		{"dots in subdomain", Tunnel{Name: "my.app", Port: 8000}, true},
		{"tcp names are free-form", Tunnel{Name: "My_Tunnel", Port: 8000, Protocol: "tcp"}, false},
		{"no port", Tunnel{Name: "myapp"}, true},
		{"port out of range", Tunnel{Name: "myapp", Port: 70000}, true},
		{"unknown protocol", Tunnel{Name: "myapp", Port: 8000, Protocol: "gopher"}, true},
	} {
		if err := validate(&tc.tunnel); (err != nil) != tc.wantErr {
			t.Errorf("%s: got %v, wantErr %v", tc.name, err, tc.wantErr)
		}
	}
}
