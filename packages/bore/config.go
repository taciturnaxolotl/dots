package main

import (
	"fmt"
	"os"
	"sort"
	"strings"

	"github.com/BurntSushi/toml"
)

// ConfigFile is the per-project file of saved tunnels, committed alongside the
// code it exposes.
const ConfigFile = "bore.toml"

// Tunnel is one saved tunnel.
//
// Labels accepts both shapes the old CLI could write: `labels = ["dev", "api"]`
// and the single `label = "dev"` it wrote in some paths. Reading both keeps
// existing files working; writing only ever produces labels.
type Tunnel struct {
	Name     string   `toml:"-"`
	Port     int      `toml:"port"`
	Protocol string   `toml:"protocol,omitempty"`
	Labels   []string `toml:"labels,omitempty"`
	Label    string   `toml:"label,omitempty"`
	Auth     bool     `toml:"auth,omitempty"`
}

// Config is bore.toml: a table per tunnel, keyed by name.
type Config struct {
	Tunnels map[string]*Tunnel
	// order preserves the order tunnels appear in the file, so rewriting one
	// does not shuffle the rest.
	order []string
}

// LoadConfig reads bore.toml from the working directory. A missing file is not
// an error; it just means no saved tunnels.
func LoadConfig() (*Config, error) {
	cfg := &Config{Tunnels: map[string]*Tunnel{}}

	raw, err := os.ReadFile(ConfigFile)
	if os.IsNotExist(err) {
		return cfg, nil
	}
	if err != nil {
		return nil, err
	}

	var tables map[string]toml.Primitive
	meta, err := toml.Decode(string(raw), &tables)
	if err != nil {
		return nil, fmt.Errorf("%s: %w", ConfigFile, err)
	}

	for _, key := range meta.Keys() {
		// Only top-level table headers name a tunnel; their keys appear too.
		if len(key) != 1 {
			continue
		}
		name := key[0]
		prim, ok := tables[name]
		if !ok {
			continue
		}
		var t Tunnel
		if err := meta.PrimitiveDecode(prim, &t); err != nil {
			return nil, fmt.Errorf("%s: [%s]: %w", ConfigFile, name, err)
		}
		t.Name = name
		if t.Label != "" {
			t.Labels = append(t.Labels, splitLabels(t.Label)...)
			t.Label = ""
		}
		cfg.Tunnels[name] = &t
		cfg.order = append(cfg.order, name)
	}
	return cfg, nil
}

// Names lists saved tunnels in file order.
func (c *Config) Names() []string { return append([]string(nil), c.order...) }

// Save writes a tunnel into bore.toml, replacing any entry of the same name.
//
// Only that tunnel's lines are touched: the rest of the file, comments
// included, is kept byte for byte. bore.toml is hand-edited and committed, so
// re-encoding the whole thing would quietly delete the notes people leave in
// it. The old CLI ran sed over a line range, which could only update keys that
// already existed and interpolated the tunnel name into a regex.
func (c *Config) Save(t *Tunnel) error {
	// http is the default, so recording it adds noise to the file.
	saved := *t
	if saved.Protocol == "http" {
		saved.Protocol = ""
	}

	var table strings.Builder
	fmt.Fprintf(&table, "[%s]\n", saved.Name)
	if err := toml.NewEncoder(&table).Encode(&saved); err != nil {
		return err
	}

	raw, err := os.ReadFile(ConfigFile)
	if err != nil && !os.IsNotExist(err) {
		return err
	}

	updated := spliceTable(string(raw), saved.Name, table.String())

	if _, exists := c.Tunnels[saved.Name]; !exists {
		c.order = append(c.order, saved.Name)
	}
	c.Tunnels[saved.Name] = &saved
	return os.WriteFile(ConfigFile, []byte(updated), 0o644)
}

// spliceTable replaces the [name] table in a TOML document, or appends it.
func spliceTable(doc, name, table string) string {
	lines := strings.Split(doc, "\n")
	header := "[" + name + "]"

	start := -1
	for i, line := range lines {
		if strings.HasPrefix(strings.TrimSpace(line), header) {
			start = i
			break
		}
	}
	if start < 0 {
		if doc != "" && !strings.HasSuffix(doc, "\n") {
			doc += "\n"
		}
		if doc != "" {
			doc += "\n"
		}
		return doc + table
	}

	// Everything up to the next table header belongs to this one.
	end := len(lines)
	for i := start + 1; i < len(lines); i++ {
		if strings.HasPrefix(strings.TrimSpace(lines[i]), "[") {
			end = i
			break
		}
	}

	rest := strings.Join(lines[end:], "\n")
	out := strings.Join(lines[:start], "\n")
	if out != "" {
		out += "\n"
	}
	out += table
	if rest != "" {
		out += "\n" + rest
	}
	return out
}

// decodeTOML is a thin wrapper so tests can round-trip what we generate.
func decodeTOML(doc string, v any) error {
	_, err := toml.Decode(doc, v)
	return err
}

// splitLabels accepts the comma-joined form the old CLI passed around.
func splitLabels(s string) []string {
	var out []string
	for _, part := range strings.Split(s, ",") {
		if part = strings.TrimSpace(part); part != "" {
			out = append(out, part)
		}
	}
	return out
}

// LabelString is the comma-joined form frps metadata carries.
func (t *Tunnel) LabelString() string { return strings.Join(t.Labels, ",") }

func (t *Tunnel) protocolOrDefault() string {
	if t.Protocol == "" {
		return "http"
	}
	return t.Protocol
}

// sortedNames is used where deterministic output matters more than file order.
func sortedNames(m map[string]*Tunnel) []string {
	names := make([]string, 0, len(m))
	for name := range m {
		names = append(names, name)
	}
	sort.Strings(names)
	return names
}
