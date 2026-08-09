package main

import (
	"fmt"
	"net"
	"testing"
	"time"
)

// collect is an events sink that hands flows and notices to a test.
func collect() (events, chan flow, chan notice) {
	flows, notices := make(chan flow, 8), make(chan notice, 8)
	return events{
		request: func(request) {},
		flow:    func(f flow) { flows <- f },
		notice:  func(n notice) { notices <- n },
		header:  func(headerRow) {},
		open:    func(int) {},
	}, flows, notices
}

func waitFor[T any](t *testing.T, ch chan T, what string) T {
	t.Helper()
	select {
	case v := <-ch:
		return v
	case <-time.After(5 * time.Second):
		t.Fatalf("no %s reported", what)
	}
	var zero T
	return zero
}

// echoTCP is a local service that answers whatever it is told, so a relay can
// be measured in both directions.
func echoTCP(t *testing.T) int {
	t.Helper()
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { listener.Close() })
	go func() {
		for {
			conn, err := listener.Accept()
			if err != nil {
				return
			}
			go func() {
				defer conn.Close()
				buf := make([]byte, 512)
				n, err := conn.Read(buf)
				if err != nil {
					return
				}
				conn.Write(append([]byte("echo:"), buf[:n]...))
			}()
		}
	}()
	return listener.Addr().(*net.TCPAddr).Port
}

func TestTCPRelayCountsBothDirections(t *testing.T) {
	ev, flows, _ := collect()
	port, err := startTCP(echoTCP(t), ev)
	if err != nil {
		t.Fatal(err)
	}

	conn, err := net.Dial("tcp", fmt.Sprintf("127.0.0.1:%d", port))
	if err != nil {
		t.Fatal(err)
	}
	if _, err := conn.Write([]byte("hello")); err != nil {
		t.Fatal(err)
	}
	buf := make([]byte, 64)
	n, err := conn.Read(buf)
	if err != nil {
		t.Fatal(err)
	}
	if got := string(buf[:n]); got != "echo:hello" {
		t.Errorf("relayed %q, want %q", got, "echo:hello")
	}
	conn.Close()

	f := waitFor(t, flows, "flow")
	if f.up != 5 || f.down != 10 {
		t.Errorf("counted ↑%d ↓%d, want ↑5 ↓10", f.up, f.down)
	}
	if f.failed {
		t.Error("a completed conversation should not be marked failed")
	}
}

// A dead local port is the everyday case: the tunnel is up before the service
// is. It should say so rather than dropping the connection silently.
func TestTCPRelayReportsADeadTarget(t *testing.T) {
	dead, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	target := dead.Addr().(*net.TCPAddr).Port
	dead.Close()

	ev, flows, notices := collect()
	port, err := startTCP(target, ev)
	if err != nil {
		t.Fatal(err)
	}

	conn, err := net.Dial("tcp", fmt.Sprintf("127.0.0.1:%d", port))
	if err != nil {
		t.Fatal(err)
	}
	defer conn.Close()

	if f := waitFor(t, flows, "flow"); !f.failed {
		t.Error("a refused connection should be marked failed")
	}
	if n := waitFor(t, notices, "notice"); n.label != "local" {
		t.Errorf("notice blamed %q, want %q", n.label, "local")
	}
}

func TestUDPRelayCarriesRepliesBack(t *testing.T) {
	service, err := net.ListenPacket("udp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { service.Close() })
	go func() {
		buf := make([]byte, 512)
		for {
			n, addr, err := service.ReadFrom(buf)
			if err != nil {
				return
			}
			service.WriteTo(append([]byte("echo:"), buf[:n]...), addr)
		}
	}()

	ev, _, _ := collect()
	port, err := startUDP(service.LocalAddr().(*net.UDPAddr).Port, ev)
	if err != nil {
		t.Fatal(err)
	}

	conn, err := net.Dial("udp", fmt.Sprintf("127.0.0.1:%d", port))
	if err != nil {
		t.Fatal(err)
	}
	defer conn.Close()

	if _, err := conn.Write([]byte("ping")); err != nil {
		t.Fatal(err)
	}
	conn.SetReadDeadline(time.Now().Add(5 * time.Second))
	buf := make([]byte, 64)
	n, err := conn.Read(buf)
	if err != nil {
		t.Fatal(err)
	}
	if got := string(buf[:n]); got != "echo:ping" {
		t.Errorf("relayed %q, want %q", got, "echo:ping")
	}
}

func TestPluralDropsTheSForOne(t *testing.T) {
	for _, c := range []struct {
		n          int
		noun, want string
	}{
		{1, "connections", "1 connection"},
		{2, "connections", "2 connections"},
		{0, "requests", "0 requests"},
	} {
		if got := plural(c.n, c.noun); got != c.want {
			t.Errorf("plural(%d, %q) = %q, want %q", c.n, c.noun, got, c.want)
		}
	}
}
