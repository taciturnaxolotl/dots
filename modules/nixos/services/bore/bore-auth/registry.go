package main

import (
	"encoding/json"
	"log"
	"net/http"
	"sync"
	"time"
)

// The registry is the authorization oracle: which subdomains exist, and which
// of them are gated.
//
// frps tells us directly through its server plugin hooks, so this is push, not
// poll. That matters for more than tidiness. When this data came from polling
// the frps admin API, a failed or slow fetch left the map empty, an empty map
// meant "no auth metadata", and "no auth metadata" meant allow: a stats
// request failing would quietly open every protected tunnel. Here, if frps
// accepted a proxy we heard about it, and anything we have not heard about
// does not exist.
type registry struct {
	mu      sync.RWMutex
	bySub   map[string]tunnel
	synced  bool
	syncErr error
}

// tunnel is one proxy as frps described it.
type tunnel struct {
	name      string
	subdomain string
	gated     bool // metadata asked for authentication
}

func newRegistry() *registry {
	return &registry{bySub: map[string]tunnel{}}
}

func (r *registry) add(t tunnel) {
	if t.subdomain == "" {
		return
	}
	r.mu.Lock()
	defer r.mu.Unlock()
	r.bySub[t.subdomain] = t
}

// removeByName drops a proxy on CloseProxy, which identifies it by name only.
// Tunnels are few, so a scan is cheaper than a second map to keep in step.
func (r *registry) removeByName(name string) {
	r.mu.Lock()
	defer r.mu.Unlock()
	for sub, t := range r.bySub {
		if t.name == name {
			delete(r.bySub, sub)
			return
		}
	}
}

// lookup reports what we know about a subdomain. known is false when no proxy
// claims it; ready is false until the startup sync has succeeded, before which
// we know nothing and must not let anything through.
func (r *registry) lookup(subdomain string) (t tunnel, known, ready bool) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	t, known = r.bySub[subdomain]
	return t, known, r.synced
}

// sync seeds the registry from the frps admin API.
//
// Hooks only fire on change, so a restart would otherwise leave us blind to
// every tunnel that already exists. Until this succeeds the registry refuses
// to answer, which is why it retries rather than giving up.
func (r *registry) sync() {
	for attempt := 0; ; attempt++ {
		proxies, err := fetchProxies()
		if err == nil {
			seeded := map[string]tunnel{}
			for _, p := range proxies {
				if t, ok := p.tunnel(); ok {
					seeded[t.subdomain] = t
				}
			}
			r.mu.Lock()
			// Hooks may have landed while we were fetching; they are newer.
			for sub, t := range r.bySub {
				seeded[sub] = t
			}
			r.bySub = seeded
			r.synced = true
			r.syncErr = nil
			r.mu.Unlock()

			log.Printf("registry synced: %d tunnels", len(seeded))
			return
		}

		r.mu.Lock()
		r.syncErr = err
		r.mu.Unlock()
		log.Printf("registry sync failed (attempt %d): %v", attempt+1, err)
		time.Sleep(min(time.Duration(attempt+1)*2*time.Second, 30*time.Second))
	}
}

// frp server plugin protocol. frps POSTs to the hook with ?op=<operation> and
// expects a verdict; unchange means "accept as submitted".
type hookRequest struct {
	Content json.RawMessage `json:"content"`
}

type hookResponse struct {
	Reject       bool   `json:"reject"`
	RejectReason string `json:"reject_reason,omitempty"`
	Unchange     bool   `json:"unchange"`
}

type newProxyContent struct {
	ProxyName string            `json:"proxy_name"`
	ProxyType string            `json:"proxy_type"`
	SubDomain string            `json:"subdomain"`
	Metas     map[string]string `json:"metas"`
}

type closeProxyContent struct {
	ProxyName string `json:"proxy_name"`
}

func (r *registry) handleHook(w http.ResponseWriter, req *http.Request) {
	var body hookRequest
	if err := json.NewDecoder(req.Body).Decode(&body); err != nil {
		http.Error(w, "bad request", http.StatusBadRequest)
		return
	}

	switch op := req.URL.Query().Get("op"); op {
	case "NewProxy":
		var content newProxyContent
		if err := json.Unmarshal(body.Content, &content); err != nil {
			http.Error(w, "bad content", http.StatusBadRequest)
			return
		}
		t := tunnel{
			name:      content.ProxyName,
			subdomain: content.SubDomain,
			gated:     content.Metas["auth"] == "indiko",
		}
		r.add(t)
		log.Printf("hook: proxy %q claimed %q (gated=%v)", t.name, t.subdomain, t.gated)

	case "CloseProxy":
		var content closeProxyContent
		if err := json.Unmarshal(body.Content, &content); err != nil {
			http.Error(w, "bad content", http.StatusBadRequest)
			return
		}
		r.removeByName(content.ProxyName)
		log.Printf("hook: proxy %q closed", content.ProxyName)

	default:
		log.Printf("hook: ignoring op %q", op)
	}

	writeJSON(w, hookResponse{Unchange: true})
}

// handleAuthCheck is what Caddy's forward_auth calls for every request to a
// tunnel. 200 lets the request through; a redirect sends the visitor to log in.
func (r *registry) handleAuthCheck(w http.ResponseWriter, req *http.Request) {
	host := req.Header.Get("X-Forwarded-Host")
	if host == "" {
		host = req.Host
	}

	subdomain := extractSubdomain(host)
	if subdomain == "" {
		w.WriteHeader(http.StatusOK) // the base domain, not a tunnel
		return
	}

	t, known, ready := r.lookup(subdomain)
	switch {
	case !ready:
		// We have not managed to learn what exists yet, so we cannot tell a
		// public tunnel from a gated one. Refuse rather than guess.
		http.Error(w, "authentication service is starting up", http.StatusServiceUnavailable)
		return
	case !known:
		// No proxy claims this subdomain, so there is nothing to protect.
		// frps answers with its 404.
		w.WriteHeader(http.StatusOK)
		return
	case !t.gated:
		w.WriteHeader(http.StatusOK)
		return
	}

	session, err := getSession(req)
	if err != nil || session == nil || time.Now().After(session.ExpiresAt) {
		redirectToLogin(w, req, host)
		return
	}

	w.Header().Set("X-Auth-User", session.UserID)
	w.Header().Set("X-Auth-Name", session.Name)
	w.Header().Set("X-Auth-Email", session.Email)
	w.WriteHeader(http.StatusOK)
}

func writeJSON(w http.ResponseWriter, v any) {
	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(v); err != nil {
		log.Printf("failed to write response: %v", err)
	}
}
