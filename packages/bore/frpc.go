package main

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"os/exec"
	"regexp"
	"strconv"
	"strings"
	"syscall"
	"time"

	"github.com/BurntSushi/toml"
)

// frpcConfig is the config handed to frpc. It is marshalled rather than built
// by string concatenation, so a label or subdomain containing a quote cannot
// produce a broken file.
type frpcConfig struct {
	ServerAddr string        `toml:"serverAddr"`
	ServerPort int           `toml:"serverPort"`
	Transport  frpcTransport `toml:"transport"`
	Auth       frpcAuth      `toml:"auth"`
	Log        frpcLog       `toml:"log"`
	WebServer  *frpcWeb      `toml:"webServer,omitempty"`
	Proxies    []frpcProxy   `toml:"proxies"`
}

// frpcTransport tunes the link to the server.
//
// poolCount is deliberately not set. It pre-opens connections to the server so
// a visitor does not wait for one, which sounds like the fix for a slow
// tunnel, but tcpMux already carries work connections over the control
// connection: measured against the live server, poolCount = 5 and poolCount =
// 0 were indistinguishable at ~210ms a request. The time is distance.
type frpcTransport struct {
	TCPMux bool `toml:"tcpMux"`
}

type frpcLog struct {
	To    string `toml:"to"`
	Level string `toml:"level"`
	// We restyle what frpc prints, so its own colours would fight ours.
	DisablePrintColor bool `toml:"disablePrintColor"`
}

type frpcAuth struct {
	Method      string `toml:"method"`
	TokenSource struct {
		Type string `toml:"type"`
		File struct {
			Path string `toml:"path"`
		} `toml:"file"`
	} `toml:"tokenSource"`
}

type frpcWeb struct {
	Addr string `toml:"addr"`
	Port int    `toml:"port"`
}

type frpcProxy struct {
	Name       string            `toml:"name"`
	Type       string            `toml:"type"`
	LocalIP    string            `toml:"localIP"`
	LocalPort  int               `toml:"localPort"`
	Subdomain  string            `toml:"subdomain,omitempty"`
	RemotePort *int              `toml:"remotePort,omitempty"`
	Metadatas  map[string]string `toml:"metadatas,omitempty"`
}

// buildConfig turns a tunnel into an frpc config. adminPort is non-zero for
// tcp and udp, where the allocated remote port has to be read back from frpc's
// own API afterwards.
func buildConfig(t *Tunnel, localPort, adminPort int, verbose bool) frpcConfig {
	cfg := frpcConfig{
		ServerAddr: serverAddr,
		ServerPort: serverPortNumber(),
	}
	cfg.Transport.TCPMux = true

	cfg.Auth.Method = "token"
	cfg.Auth.TokenSource.Type = "file"
	cfg.Auth.TokenSource.File.Path = authTokenFile

	// frpc narrates its startup at info level, which is six lines saying it
	// did what it was asked. Warnings and errors are worth seeing; the rest we
	// say ourselves, in fewer words.
	cfg.Log.To = "console"
	cfg.Log.Level = "warn"
	cfg.Log.DisablePrintColor = true
	if verbose {
		cfg.Log.Level = "info"
	}

	proxy := frpcProxy{
		Name:      t.Name,
		Type:      t.protocolOrDefault(),
		LocalIP:   "127.0.0.1",
		LocalPort: localPort,
		Metadatas: map[string]string{},
	}
	if labels := t.LabelString(); labels != "" {
		proxy.Metadatas["labels"] = labels
	}
	if t.Auth {
		proxy.Metadatas["auth"] = "indiko"
	}
	if len(proxy.Metadatas) == 0 {
		proxy.Metadatas = nil
	}

	if proxy.Type == "http" {
		proxy.Subdomain = t.Name
	} else {
		zero := 0 // let the server allocate
		proxy.RemotePort = &zero
		cfg.WebServer = &frpcWeb{Addr: "127.0.0.1", Port: adminPort}
	}

	cfg.Proxies = []frpcProxy{proxy}
	return cfg
}

// writeConfig renders the frpc config to a temporary file.
func writeConfig(cfg frpcConfig) (string, error) {
	f, err := os.CreateTemp("", "bore-*.toml")
	if err != nil {
		return "", err
	}
	defer f.Close()

	if err := toml.NewEncoder(f).Encode(cfg); err != nil {
		os.Remove(f.Name())
		return "", err
	}
	return f.Name(), nil
}

// serverPortNumber parses the port baked in at build time.
func serverPortNumber() int {
	port, err := strconv.Atoi(serverPort)
	if err != nil {
		return 7000
	}
	return port
}

// freePort asks the kernel for an unused port, for frpc's admin API.
func freePort() (int, error) {
	l, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		return 0, err
	}
	defer l.Close()
	return l.Addr().(*net.TCPAddr).Port, nil
}

// listening reports whether anything is serving on the local port, so we can
// warn before opening a tunnel to nothing.
func listening(port int) bool {
	conn, err := net.DialTimeout("tcp", fmt.Sprintf("127.0.0.1:%d", port), time.Second)
	if err != nil {
		return false
	}
	conn.Close()
	return true
}

// frpcLine picks apart one of frpc's log lines:
//
//	2026-08-08 19:05:31.795 [E] [proxy/proxy.go:202] [runid] [name] message
//
// The timestamp, level, source file and ids are frpc talking to its own
// developers. What is left is occasionally worth passing on.
var frpcLine = regexp.MustCompile(`^\S+ \S+ \[([IWED])\] \[[^\]]+\] (.*)$`)

// run starts frpc and reports what happens in bore's own words. Verbose mode
// passes frpc's output through untouched, for when the translation is hiding
// the thing you need.
func run(ctx context.Context, t *Tunnel, configPath string, adminPort int, verbose bool, note func(label, text string)) error {
	cmd := exec.CommandContext(ctx, frpcBin, "-c", configPath)
	cmd.Stdin = os.Stdin

	out, err := cmd.StdoutPipe()
	if err != nil {
		return err
	}
	cmd.Stderr = cmd.Stdout

	if err := cmd.Start(); err != nil {
		return err
	}
	go narrate(out, t, adminPort, verbose, note)

	// ctrl-c reaches frpc too, and closing a tunnel on purpose is not a
	// failure. Neither is us stopping it because the view was closed.
	err = cmd.Wait()
	var exit *exec.ExitError
	if errors.As(err, &exit) && stoppedBySignal(exit) {
		return nil
	}
	if errors.Is(ctx.Err(), context.Canceled) {
		return nil
	}
	return err
}

func stoppedBySignal(exit *exec.ExitError) bool {
	status, ok := exit.Sys().(syscall.WaitStatus)
	return ok && status.Signaled()
}

func narrate(out io.Reader, t *Tunnel, adminPort int, verbose bool, note func(label, text string)) {
	scanner := bufio.NewScanner(out)

	var lastProblem string
	repeats := 0

	for scanner.Scan() {
		line := scanner.Text()
		if verbose {
			fmt.Println(line)
			continue
		}

		match := frpcLine.FindStringSubmatch(line)
		if match == nil {
			if strings.TrimSpace(line) != "" {
				fmt.Println(line)
			}
			continue
		}
		level, message := match[1], stripIDs(match[2])

		switch {
		case strings.Contains(message, "start proxy success"):
			if adminPort == 0 {
				continue // the header already says where it is
			}
			if addr, err := remoteAddr(adminPort, t); err == nil {
				note("remote", addr)
			}

		case level == "E" || level == "W":
			label, message := translate(message, t)
			// frpc retries a failing connection every second or so; saying it
			// once is informative, saying it forty times is noise.
			if message == lastProblem {
				repeats++
				continue
			}
			if repeats > 0 {
				note("", dim(fmt.Sprintf("(repeated %d times)", repeats)))
			}
			lastProblem, repeats = message, 0
			note(label, message)
		}
	}
	if repeats > 0 {
		note("", dim(fmt.Sprintf("(repeated %d times)", repeats)))
	}
}

// translate puts frpc's most common complaints in terms of what the user did,
// rather than what frpc was doing at the time.
func translate(message string, t *Tunnel) (label, text string) {
	switch {
	case strings.Contains(message, "connect to local service") && strings.Contains(message, "connection refused"):
		return "local", fmt.Sprintf("nothing is listening on localhost:%d", t.Port)
	case strings.Contains(message, "login to server failed"), strings.Contains(message, "connect to server error"):
		return "server", strings.TrimPrefix(message, "login to server failed: ")
	}
	return "frpc", message
}

// stripIDs removes the run id and proxy name frpc prefixes to every message.
func stripIDs(message string) string {
	for strings.HasPrefix(message, "[") {
		end := strings.Index(message, "]")
		if end < 0 {
			break
		}
		message = strings.TrimSpace(message[end+1:])
	}
	return message
}

// remoteAddr asks frpc which address the server gave us.
func remoteAddr(adminPort int, t *Tunnel) (string, error) {
	client := &http.Client{Timeout: 3 * time.Second}
	url := fmt.Sprintf("http://127.0.0.1:%d/api/status", adminPort)

	// frpc publishes the address a moment after it logs success.
	var lastErr error
	for attempt := 0; attempt < 10; attempt++ {
		time.Sleep(300 * time.Millisecond)

		resp, err := client.Get(url)
		if err != nil {
			lastErr = err
			continue
		}
		var status map[string][]struct {
			Name       string `json:"name"`
			RemoteAddr string `json:"remote_addr"`
		}
		err = json.NewDecoder(resp.Body).Decode(&status)
		resp.Body.Close()
		if err != nil {
			lastErr = err
			continue
		}
		for _, proxies := range status {
			for _, p := range proxies {
				if p.Name == t.Name && p.RemoteAddr != "" {
					return serverAddr + strings.TrimPrefix(p.RemoteAddr, strings.Split(p.RemoteAddr, ":")[0]), nil
				}
			}
		}
		lastErr = fmt.Errorf("no address for %q yet", t.Name)
	}
	return "", lastErr
}
