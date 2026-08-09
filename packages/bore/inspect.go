package main

import (
	"fmt"
	"log"
	"net"
	"net/http"
	"net/http/httputil"
	"net/url"
	"strings"
	"time"

	"charm.land/lipgloss/v2"
)

// The inspector sits between the tunnel and your service, so bore can say what
// is actually going through it. frpc is pointed at this listener instead of
// your port, and it forwards on. That is the same trick ngrok's agent uses:
// requests are only visible to something on the path.
//
// http only. tcp and udp go through startStream, which counts what it can.
type inspector struct {
	target int
	port   int
	// sink receives every request. The plain renderer prints them; the TUI
	// keeps them in a list under a header that stays put.
	sink func(request)
}

// proxyLog turns ReverseProxy's internal logging into one of our own lines.
//
// It logs through the standard logger by default, which writes to stderr with
// a timestamp, in nobody's style, straight through whatever we are drawing.
type proxyLog struct {
	note func(notice)
}

func (l proxyLog) Write(p []byte) (int, error) {
	message := strings.TrimSpace(string(p))
	message = strings.TrimPrefix(message, "httputil: ReverseProxy ")

	// The common one by far: a dev server restarting, or a visitor navigating
	// away from a page whose response was still arriving.
	if strings.Contains(message, "unexpected EOF") || strings.Contains(message, "body copy") {
		// A dev server restarting or a visitor navigating away. It says its
		// piece and fades.
		l.note(notice{label: "local", text: "the response ended early"})
		return len(p), nil
	}
	l.note(notice{label: "local", text: message})
	return len(p), nil
}

// request is one exchange through the tunnel.
type request struct {
	at     time.Time
	method string
	path   string
	status int
	took   time.Duration
	bytes  int64
}

func (r request) render(width int) string {
	return trafficLine{
		at:          r.at,
		verb:        r.method,
		verbStyle:   methodStyle,
		subject:     r.path,
		status:      fmt.Sprint(r.status),
		statusStyle: statusStyle(r.status),
		took:        r.took,
		bytes:       r.bytes,
	}.render(width)
}

func startInspector(target int, ev events) (*inspector, error) {
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		return nil, err
	}
	in := &inspector{target: target, port: listener.Addr().(*net.TCPAddr).Port, sink: ev.request}

	upstream, err := url.Parse(fmt.Sprintf("http://127.0.0.1:%d", target))
	if err != nil {
		return nil, err
	}

	proxy := httputil.NewSingleHostReverseProxy(upstream)
	// The default transport keeps two idle connections per host, so a page
	// pulling a dozen assets through here would queue behind them.
	transport := http.DefaultTransport.(*http.Transport).Clone()
	transport.MaxIdleConnsPerHost = 64
	transport.IdleConnTimeout = 90 * time.Second
	proxy.Transport = transport
	proxy.ErrorLog = log.New(proxyLog{ev.notice}, "", 0)
	// Stream responses through as they arrive rather than buffering, so server
	// sent events and long polling behave the way they would without us.
	proxy.FlushInterval = -1
	proxy.ErrorHandler = func(w http.ResponseWriter, r *http.Request, err error) {
		w.WriteHeader(http.StatusBadGateway)
		fmt.Fprintf(w, "bore: could not reach localhost:%d", target)
	}
	// The upstream should see the host the visitor asked for.
	director := proxy.Director
	proxy.Director = func(r *http.Request) {
		host := r.Host
		director(r)
		r.Host = host
	}

	server := &http.Server{
		Handler:           in.record(proxy),
		ReadHeaderTimeout: 30 * time.Second,
	}
	go server.Serve(listener)

	return in, nil
}

// record wraps the proxy to time each request and print a line for it.
func (in *inspector) record(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		started := time.Now()
		recorder := &statusRecorder{ResponseWriter: w, status: http.StatusOK}

		next.ServeHTTP(recorder, r)

		in.print(r, recorder, time.Since(started))
	})
}

func (in *inspector) print(r *http.Request, rec *statusRecorder, took time.Duration) {
	path := r.URL.Path
	if r.URL.RawQuery != "" {
		path += "?" + r.URL.RawQuery
	}
	in.sink(request{
		at:     time.Now(),
		method: r.Method,
		path:   path,
		status: rec.status,
		took:   took,
		bytes:  rec.written,
	})
}

// statusRecorder remembers what the handler answered, which the standard
// ResponseWriter does not expose.
type statusRecorder struct {
	http.ResponseWriter
	status  int
	written int64
	wrote   bool
}

func (r *statusRecorder) WriteHeader(status int) {
	if !r.wrote {
		r.status, r.wrote = status, true
	}
	r.ResponseWriter.WriteHeader(status)
}

func (r *statusRecorder) Write(b []byte) (int, error) {
	r.wrote = true
	n, err := r.ResponseWriter.Write(b)
	r.written += int64(n)
	return n, err
}

// Flush keeps streaming responses streaming through the wrapper.
func (r *statusRecorder) Flush() {
	if f, ok := r.ResponseWriter.(http.Flusher); ok {
		f.Flush()
	}
}

var methodStyle = lipgloss.NewStyle().Foreground(lipgloss.Color("6"))

// statusStyle colours by class, so a wall of requests can be skimmed.
func statusStyle(status int) lipgloss.Style {
	switch {
	case status >= 500:
		return failStyle
	case status >= 400:
		return warnStyle
	case status >= 300:
		return lipgloss.NewStyle().Foreground(lipgloss.Color("6"))
	}
	return labelStyle
}
