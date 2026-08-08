package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"sync"
	"time"
)

// The status page's data and the authorization decision used to share one
// cache, which is why a failed stats fetch could open a gated tunnel. They are
// separate now: the registry decides access, and this only feeds the dashboard.
// If this is stale or missing, the page shows old numbers and nothing else
// changes.
//
// It also exists so the frps admin API does not have to be proxied to the
// public internet. The dashboard reads these fields and no others.
type statusCache struct {
	mu   sync.RWMutex
	body []byte
	at   time.Time
}

const statusInterval = 10 * time.Second

// The projection the dashboard consumes. Field names match what frps used to
// return, so the page reads the same keys from a source we control.
type statusResponse struct {
	Server  serverStats  `json:"server"`
	Proxies []proxyStats `json:"proxies"`
}

type serverStats struct {
	ClientCounts    int   `json:"clientCounts"`
	CurConns        int   `json:"curConns"`
	TotalTrafficIn  int64 `json:"totalTrafficIn"`
	TotalTrafficOut int64 `json:"totalTrafficOut"`
}

type proxyStats struct {
	Name            string    `json:"name"`
	Type            string    `json:"type"`
	Status          string    `json:"status"`
	LastStartTime   string    `json:"lastStartTime"`
	TodayTrafficIn  int64     `json:"todayTrafficIn"`
	TodayTrafficOut int64     `json:"todayTrafficOut"`
	Conf            proxyConf `json:"conf"`
}

type proxyConf struct {
	Subdomain  string            `json:"subdomain"`
	RemotePort int               `json:"remotePort,omitempty"`
	Metadatas  map[string]string `json:"metadatas"`
}

func (s *statusCache) run() {
	s.refresh()
	for range time.Tick(statusInterval) {
		s.refresh()
	}
}

func (s *statusCache) refresh() {
	info, err := fetchServerInfo()
	if err != nil {
		log.Printf("status: server info: %v", err)
		return
	}
	proxies, err := fetchProxies()
	if err != nil {
		log.Printf("status: proxy list: %v", err)
		return
	}

	out := statusResponse{
		Server: serverStats{
			ClientCounts:    info.ClientCounts,
			CurConns:        info.CurConns,
			TotalTrafficIn:  info.TotalTrafficIn,
			TotalTrafficOut: info.TotalTrafficOut,
		},
		Proxies: make([]proxyStats, 0, len(proxies)),
	}
	for _, p := range proxies {
		conf, err := p.conf()
		if err != nil {
			continue
		}
		out.Proxies = append(out.Proxies, proxyStats{
			Name:            p.Name,
			Type:            p.Type,
			Status:          p.Status,
			LastStartTime:   p.LastStartTime,
			TodayTrafficIn:  p.TodayTrafficIn,
			TodayTrafficOut: p.TodayTrafficOut,
			Conf: proxyConf{
				Subdomain:  conf.Subdomain,
				RemotePort: conf.RemotePort,
				Metadatas: map[string]string{
					"labels": conf.Metadatas["labels"],
					"auth":   conf.Metadatas["auth"],
				},
			},
		})
	}

	body, err := json.Marshal(out)
	if err != nil {
		log.Printf("status: encode: %v", err)
		return
	}

	s.mu.Lock()
	s.body, s.at = body, time.Now()
	s.mu.Unlock()
}

func (s *statusCache) handle(w http.ResponseWriter, _ *http.Request) {
	s.mu.RLock()
	body, at := s.body, s.at
	s.mu.RUnlock()

	if body == nil {
		http.Error(w, `{"error":"no data yet"}`, http.StatusServiceUnavailable)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Cache-Control", fmt.Sprintf("max-age=%d", int(statusInterval.Seconds())))
	w.Header().Set("Last-Modified", at.UTC().Format(http.TimeFormat))
	w.Write(body)
}
