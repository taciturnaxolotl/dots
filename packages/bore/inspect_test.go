package main

import (
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"strconv"
	"strings"
	"testing"
)

// TestInspectorForwards is the property that matters: the hop must be
// invisible to both ends.
func TestInspectorForwards(t *testing.T) {
	upstream := httptest.NewServer(http.HandlerFunc(
		func(w http.ResponseWriter, r *http.Request) {
			switch r.URL.Path {
			case "/boom":
				w.WriteHeader(http.StatusInternalServerError)
				fmt.Fprint(w, "no")
			case "/echo":
				w.Header().Set("X-Seen-Host", r.Host)
				body, _ := io.ReadAll(r.Body)
				fmt.Fprintf(w, "got %s %s", r.Method, body)
			default:
				fmt.Fprint(w, "hello")
			}
		}))
	defer upstream.Close()

	target, err := strconv.Atoi(strings.TrimPrefix(upstream.URL, "http://127.0.0.1:"))
	if err != nil {
		t.Fatal(err)
	}
	in, err := startInspector(target, discard())
	if err != nil {
		t.Fatal(err)
	}
	base := fmt.Sprintf("http://127.0.0.1:%d", in.port)

	resp, err := http.Get(base + "/")
	if err != nil {
		t.Fatal(err)
	}
	body, _ := io.ReadAll(resp.Body)
	if string(body) != "hello" {
		t.Errorf("body through the proxy: %q", body)
	}

	// The upstream must see the host the visitor asked for, not our listener.
	req, _ := http.NewRequest("POST", base+"/echo", nil)
	req.Host = "myapp.bore.dunkirk.sh"
	resp, err = http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	if got := resp.Header.Get("X-Seen-Host"); got != "myapp.bore.dunkirk.sh" {
		t.Errorf("upstream saw Host %q, want the original", got)
	}

	// Status codes pass through unchanged.
	resp, _ = http.Get(base + "/boom")
	if resp.StatusCode != 500 {
		t.Errorf("status through the proxy: %d", resp.StatusCode)
	}

	// A dead upstream becomes a 502 rather than a hang.
	dead, err := startInspector(19999, discard())
	if err != nil {
		t.Fatal(err)
	}
	resp, err = http.Get(fmt.Sprintf("http://127.0.0.1:%d/", dead.port))
	if err != nil {
		t.Fatal(err)
	}
	if resp.StatusCode != http.StatusBadGateway {
		t.Errorf("unreachable upstream: got %d, want 502", resp.StatusCode)
	}
}

// A warning holds until a request answers it; an error holds regardless.
func TestNoticesGoStaleOnlyOnceARequestFollows(t *testing.T) {
	warned := notice{after: 3}
	if warned.stale(3) {
		t.Error("a warning should hold while the tunnel is quiet")
	}
	if !warned.stale(4) {
		t.Error("a request after the warning should retire it")
	}
	if (notice{after: 3, fatal: true}).stale(99) {
		t.Error("a fatal notice should stay until it is superseded")
	}
}

// discard is an events sink for tests that only care about what got proxied.
func discard() events {
	return events{
		request: func(request) {},
		flow:    func(flow) {},
		notice:  func(notice) {},
		header:  func(headerRow) {},
		open:    func(int) {},
	}
}

// A dropped control connection is a moment; a refused token is a state.
func TestServerTroubleIsOnlyFatalWhenRetryingCannotHelp(t *testing.T) {
	tunnel := &Tunnel{Name: "myapp", Port: 8000}

	if _, _, fatal := translate("connect to server error: EOF", tunnel); fatal {
		t.Error("a dropped connection should warn, not kill the tunnel")
	}
	if _, _, fatal := translate("login to server failed: token mismatch", tunnel); !fatal {
		t.Error("a refused token should be fatal")
	}
}
