package main

import (
	"encoding/json"
	"fmt"
	"net/http"
	"time"
)

// Every call to frps goes through a client with a deadline. The previous code
// used http.DefaultClient, which has none, and held the cache's write lock
// across the request: an frps that accepted the connection and never replied
// would wedge every auth check on the server.
var frpsClient = &http.Client{Timeout: 5 * time.Second}

type serverInfo struct {
	ClientCounts    int   `json:"clientCounts"`
	CurConns        int   `json:"curConns"`
	TotalTrafficIn  int64 `json:"totalTrafficIn"`
	TotalTrafficOut int64 `json:"totalTrafficOut"`
}

// proxyInfo is one entry of the frps proxy list. Conf stays raw because frps
// shapes it per proxy type.
type proxyInfo struct {
	Type            string          `json:"-"` // filled in from the endpoint
	Name            string          `json:"name"`
	Status          string          `json:"status"`
	LastStartTime   string          `json:"lastStartTime"`
	TodayTrafficIn  int64           `json:"todayTrafficIn"`
	TodayTrafficOut int64           `json:"todayTrafficOut"`
	Conf            json.RawMessage `json:"conf"`
}

type proxyConfRaw struct {
	Subdomain  string            `json:"subdomain"`
	RemotePort int               `json:"remotePort"`
	Metadatas  map[string]string `json:"metadatas"`
}

func (p proxyInfo) conf() (proxyConfRaw, error) {
	var conf proxyConfRaw
	if len(p.Conf) == 0 {
		return conf, fmt.Errorf("proxy %q has no conf", p.Name)
	}
	err := json.Unmarshal(p.Conf, &conf)
	return conf, err
}

// tunnel converts a proxy list entry into what the registry cares about.
func (p proxyInfo) tunnel() (tunnel, bool) {
	conf, err := p.conf()
	if err != nil || conf.Subdomain == "" || p.Status != "online" {
		return tunnel{}, false // only http proxies have a subdomain to gate
	}
	return tunnel{
		name:      p.Name,
		subdomain: conf.Subdomain,
		gated:     conf.Metadatas["auth"] == "indiko",
	}, true
}

func fetchServerInfo() (serverInfo, error) {
	var info serverInfo
	err := getJSON("/api/serverinfo", &info)
	return info, err
}

// proxyTypes are the kinds of tunnel bore offers. The status page used to read
// /api/proxy/http only, so tcp and udp tunnels were invisible to `bore --list`
// even though the CLI can create them.
var proxyTypes = []string{"http", "tcp", "udp"}

// fetchProxies returns every proxy, tagged with its type.
func fetchProxies() ([]proxyInfo, error) {
	var all []proxyInfo
	for _, kind := range proxyTypes {
		var list struct {
			Proxies []proxyInfo `json:"proxies"`
		}
		if err := getJSON("/api/proxy/"+kind, &list); err != nil {
			return nil, err
		}
		for _, p := range list.Proxies {
			p.Type = kind
			all = append(all, p)
		}
	}
	return all, nil
}

func getJSON(path string, out any) error {
	resp, err := frpsClient.Get(config.FrpsAPIURL + path)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("frps %s returned %s", path, resp.Status)
	}
	return json.NewDecoder(resp.Body).Decode(out)
}
