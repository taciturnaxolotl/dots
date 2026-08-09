package main

import (
	"encoding/json"
	"fmt"
	"net/http"
	"sort"
	"time"

	"charm.land/lipgloss/v2"
)

// statusResponse is what bore-auth publishes at /tunnels: the handful of
// fields the status page and this command need. The frps admin API itself
// stays on the server's localhost.
type statusResponse struct {
	Proxies []struct {
		Name   string `json:"name"`
		Type   string `json:"type"`
		Status string `json:"status"`
		Conf   struct {
			Subdomain  string            `json:"subdomain"`
			RemotePort int               `json:"remotePort"`
			Metadatas  map[string]string `json:"metadatas"`
		} `json:"conf"`
	} `json:"proxies"`
}

// runList shows what is running on the server right now.
func runList() error {
	client := &http.Client{Timeout: 10 * time.Second}

	resp, err := client.Get("https://" + domain + "/tunnels")
	if err != nil {
		return fmt.Errorf("could not reach %s: %w", domain, err)
	}
	defer resp.Body.Close()

	// A server error is an error, not an empty list. The old CLI let a 502
	// fall through to "No active tunnels".
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("%s returned %s", domain, resp.Status)
	}

	var status statusResponse
	if err := json.NewDecoder(resp.Body).Decode(&status); err != nil {
		return fmt.Errorf("could not read the tunnel list: %w", err)
	}

	online := status.Proxies[:0]
	for _, p := range status.Proxies {
		if p.Status == "online" {
			online = append(online, p)
		}
	}
	if len(online) == 0 {
		lipgloss.Println(dim("no tunnels are running"))
		return nil
	}
	sort.Slice(online, func(i, j int) bool { return online[i].Name < online[j].Name })

	names := make([]string, 0, len(online))
	for _, p := range online {
		names = append(names, p.Name)
	}
	sec := newSection(names...)

	for _, p := range online {
		var address string
		switch p.Type {
		case "http":
			address = link("https://" + p.Conf.Subdomain + "." + domain)
		case "tcp", "udp":
			address = fmt.Sprintf("%s://%s:%d", p.Type, domain, p.Conf.RemotePort)
		default:
			address = dim(p.Type)
		}
		if p.Conf.Metadatas["auth"] == "indiko" {
			address += dim("  sign-in required")
		}
		if labels := p.Conf.Metadatas["labels"]; labels != "" {
			address += dim("  " + labels)
		}
		sec.row(p.Name, address)
	}
	return nil
}

// runSaved shows the tunnels in this directory's bore.toml.
func runSaved() error {
	cfg, err := LoadConfig()
	if err != nil {
		return err
	}
	names := cfg.Names()
	if len(names) == 0 {
		lipgloss.Println(dim("no " + ConfigFile + " here"))
		return nil
	}

	sec := newSection(names...)
	for _, name := range names {
		t := cfg.Tunnels[name]

		value := fmt.Sprintf("localhost:%d", t.Port)
		if p := t.protocolOrDefault(); p != "http" {
			value += dim("  " + p)
		}
		if labels := t.LabelString(); labels != "" {
			value += dim("  " + labels)
		}
		if t.Auth {
			value += dim("  sign-in required")
		}
		sec.row(name, value)
	}
	return nil
}
