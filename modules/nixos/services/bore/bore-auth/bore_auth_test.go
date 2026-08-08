package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func init() {
	config.CookieDomain = ".bore.dunkirk.sh"
}

func TestSafeRedirect(t *testing.T) {
	home := "https://bore.dunkirk.sh"

	for _, tc := range []struct {
		in, want string
	}{
		{"", home},
		{"https://evil.example", home},
		{"https://bore.dunkirk.sh.evil.example", home},
		{"http://bore.dunkirk.sh", home}, // downgrade
		{"//evil.example", home},         // scheme-relative
		{"/dashboard", home},             // no host to trust
		{"https://app.bore.dunkirk.sh/x?y=1", "https://app.bore.dunkirk.sh/x?y=1"},
		{"https://bore.dunkirk.sh/dash", "https://bore.dunkirk.sh/dash"},
	} {
		if got := safeRedirect(tc.in); got != tc.want {
			t.Errorf("safeRedirect(%q) = %q, want %q", tc.in, got, tc.want)
		}
	}
}

// check drives handleAuthCheck the way Caddy's forward_auth does.
func check(r *registry, host string) *httptest.ResponseRecorder {
	req := httptest.NewRequest(http.MethodGet, "/.auth/check", nil)
	req.Header.Set("X-Forwarded-Host", host)
	w := httptest.NewRecorder()
	r.handleAuthCheck(w, req)
	return w
}

func TestAuthCheckFailsClosedBeforeSync(t *testing.T) {
	r := newRegistry() // not synced
	if got := check(r, "anything.bore.dunkirk.sh").Code; got != http.StatusServiceUnavailable {
		t.Errorf("before sync: got %d, want 503; an unsynced registry must not let traffic through", got)
	}
}

func TestAuthCheckGating(t *testing.T) {
	r := newRegistry()
	r.synced = true
	r.add(tunnel{name: "open", subdomain: "open"})
	r.add(tunnel{name: "shut", subdomain: "shut", gated: true})

	if got := check(r, "open.bore.dunkirk.sh").Code; got != http.StatusOK {
		t.Errorf("ungated tunnel: got %d, want 200", got)
	}
	if got := check(r, "shut.bore.dunkirk.sh").Code; got != http.StatusTemporaryRedirect {
		t.Errorf("gated tunnel without a session: got %d, want a redirect to login", got)
	}
	// No proxy claims this, so frps will answer with its 404.
	if got := check(r, "nothere.bore.dunkirk.sh").Code; got != http.StatusOK {
		t.Errorf("unclaimed subdomain: got %d, want 200", got)
	}
	if got := check(r, "bore.dunkirk.sh").Code; got != http.StatusOK {
		t.Errorf("base domain: got %d, want 200", got)
	}
}

// TestHookLifecycle is the contract with frps: a proxy appears when it is
// created and is gone when it closes.
func TestHookLifecycle(t *testing.T) {
	r := newRegistry()
	r.synced = true

	post := func(op, body string) {
		req := httptest.NewRequest(http.MethodPost, "/.frp/hook?op="+op, strings.NewReader(body))
		w := httptest.NewRecorder()
		r.handleHook(w, req)

		if w.Code != http.StatusOK {
			t.Fatalf("%s: got %d", op, w.Code)
		}
		var resp hookResponse
		if err := json.NewDecoder(w.Body).Decode(&resp); err != nil {
			t.Fatalf("%s: %v", op, err)
		}
		if resp.Reject || !resp.Unchange {
			t.Errorf("%s: got %+v, want an unchanged accept", op, resp)
		}
	}

	// The payload frps sends; "metas" is msg.NewProxy's tag for the proxy's
	// metadatas, which is where the bore CLI puts auth.
	post("NewProxy", `{"content":{"proxy_name":"myapp","proxy_type":"http",
		"subdomain":"myapp","metas":{"auth":"indiko","labels":"dev"}}}`)

	if got := check(r, "myapp.bore.dunkirk.sh").Code; got != http.StatusTemporaryRedirect {
		t.Errorf("after NewProxy: got %d, want the gate to be up", got)
	}

	post("CloseProxy", `{"content":{"proxy_name":"myapp"}}`)

	if got := check(r, "myapp.bore.dunkirk.sh").Code; got != http.StatusOK {
		t.Errorf("after CloseProxy: got %d, want the tunnel to be gone", got)
	}
}

func TestHookIgnoresOtherOps(t *testing.T) {
	r := newRegistry()
	req := httptest.NewRequest(http.MethodPost, "/.frp/hook?op=Ping", strings.NewReader(`{"content":{}}`))
	w := httptest.NewRecorder()
	r.handleHook(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("Ping: got %d, want 200; refusing an op we ignore would block clients", w.Code)
	}
}
