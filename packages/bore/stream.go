package main

import (
	"fmt"
	"io"
	"net"
	"sync"
	"sync/atomic"
	"time"
)

// A tcp or udp tunnel carries bytes nobody here can read, so there is no
// request to name. What can be counted honestly is the shape of the traffic:
// how many conversations there were, how long each lasted, and how much went
// each way. That is the same interposition the http inspector does, one layer
// down, and it is all the data there is to have without lying about payloads.
//
// udp has no connections, so a "conversation" is one source address until it
// goes quiet. That is a choice rather than a fact, which is why the line says
// datagrams and not much else.
const udpIdle = 30 * time.Second

// flow is one conversation through a tcp or udp tunnel.
type flow struct {
	at       time.Time
	protocol string
	detail   string
	took     time.Duration
	up, down int64
	failed   bool
}

// render uses the same columns as a request line, so a tcp tunnel reads like an
// http one even though the middle of it says something different.
func (f flow) render(width int) string {
	status, style := "ok", labelStyle
	if f.failed {
		status, style = "err", failStyle
	}
	return trafficLine{
		at:          f.at,
		verb:        f.protocol,
		verbStyle:   methodStyle,
		subject:     f.detail,
		status:      status,
		statusStyle: style,
		took:        f.took,
		bytes:       f.up + f.down,
	}.render(width)
}

// startStream puts a counter in front of a tcp or udp port and returns the port
// frpc should be pointed at instead.
func startStream(protocol string, target int, ev events) (int, error) {
	if protocol == "udp" {
		return startUDP(target, ev)
	}
	return startTCP(target, ev)
}

// local names the user's service. It is deliberately a hostname and not
// 127.0.0.1: a server bound only to ::1 is a normal thing for a dev server to
// do, and dialing the v4 literal gets a connection refused from a port the
// browser reaches perfectly well. Go tries every address "localhost" resolves
// to, so either family answers.
func local(port int) string {
	return fmt.Sprintf("localhost:%d", port)
}

func startTCP(target int, ev events) (int, error) {
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		return 0, err
	}
	go func() {
		for {
			conn, err := listener.Accept()
			if err != nil {
				return
			}
			go relay(conn, target, ev)
		}
	}()
	return listener.Addr().(*net.TCPAddr).Port, nil
}

// relay copies a connection through to the local service, counting both ways.
func relay(from net.Conn, target int, ev events) {
	started := time.Now()
	defer from.Close()

	to, err := net.Dial("tcp", local(target))
	if err != nil {
		ev.notice(notice{label: "local", text: fmt.Sprintf("nothing is listening on localhost:%d", target)})
		ev.flow(flow{
			at:       started,
			protocol: "tcp",
			detail:   "could not connect",
			took:     time.Since(started),
			failed:   true,
		})
		return
	}
	defer to.Close()

	ev.open(1)
	defer ev.open(-1)

	var up, down atomic.Int64
	done := make(chan struct{}, 2)
	go func() { n, _ := io.Copy(to, from); up.Store(n); done <- struct{}{} }()
	go func() { n, _ := io.Copy(from, to); down.Store(n); done <- struct{}{} }()

	// Whichever direction ends first, the conversation is over. Closing both
	// unblocks the other copy; waiting for it instead would hold the connection
	// for as long as the local service felt like keeping it, which is how a
	// client that simply walked away stayed counted as open. Half-closing would
	// be the polite alternative, but frp multiplexes the tunnel and the shutdown
	// does not survive the trip.
	<-done
	from.Close()
	to.Close()
	<-done

	ev.flow(flow{
		at:       started,
		protocol: "tcp",
		detail:   fmt.Sprintf("↑ %s  ↓ %s", size(up.Load()), size(down.Load())),
		took:     time.Since(started),
		up:       up.Load(),
		down:     down.Load(),
	})
}

// udpPeer is one source address talking to the local service, and the socket
// kept open to carry its replies back.
type udpPeer struct {
	conn    net.Conn
	at      time.Time
	last    atomic.Int64 // unix nanos, so the reaper can read it without a lock
	up      atomic.Int64
	down    atomic.Int64
	packets atomic.Int64
}

func (p *udpPeer) touch() { p.last.Store(time.Now().UnixNano()) }

func (p *udpPeer) idle() bool {
	return time.Since(time.Unix(0, p.last.Load())) > udpIdle
}

func startUDP(target int, ev events) (int, error) {
	listener, err := net.ListenPacket("udp", "127.0.0.1:0")
	if err != nil {
		return 0, err
	}

	var mu sync.Mutex
	peers := map[string]*udpPeer{}

	// retire reports the conversation and stops carrying it. Callers hold mu.
	retire := func(addr string, p *udpPeer) {
		delete(peers, addr)
		p.conn.Close()
		ev.open(-1)
		ev.flow(flow{
			at:       p.at,
			protocol: "udp",
			detail:   fmt.Sprintf("%d datagrams", p.packets.Load()),
			took:     time.Unix(0, p.last.Load()).Sub(p.at),
			up:       p.up.Load(),
			down:     p.down.Load(),
		})
	}

	go func() {
		buf := make([]byte, 64*1024)
		for {
			n, addr, err := listener.ReadFrom(buf)
			if err != nil {
				return
			}

			mu.Lock()
			p, known := peers[addr.String()]
			if !known {
				// v4 literal on purpose: a udp dial never fails, so
				// there is no refusal to fall back from.
				conn, err := net.Dial("udp", fmt.Sprintf("127.0.0.1:%d", target))
				if err != nil {
					mu.Unlock()
					ev.notice(notice{label: "local", text: fmt.Sprintf("could not reach localhost:%d", target)})
					continue
				}
				p = &udpPeer{conn: conn, at: time.Now()}
				p.touch()
				peers[addr.String()] = p
				ev.open(1)
				go carryReplies(listener, addr, p, ev)
			}
			mu.Unlock()

			p.touch()
			p.packets.Add(1)
			p.up.Add(int64(n))
			if _, err := p.conn.Write(buf[:n]); err != nil {
				mu.Lock()
				if peers[addr.String()] == p {
					retire(addr.String(), p)
				}
				mu.Unlock()
			}
		}
	}()

	// udp never says goodbye, so a conversation ends by going quiet.
	go func() {
		for range time.Tick(udpIdle / 3) {
			mu.Lock()
			for addr, p := range peers {
				if p.idle() {
					retire(addr, p)
				}
			}
			mu.Unlock()
		}
	}()

	return listener.LocalAddr().(*net.UDPAddr).Port, nil
}

// carryReplies sends whatever the local service answers back to the peer that
// asked, which is what makes this a relay rather than a sink.
func carryReplies(listener net.PacketConn, addr net.Addr, p *udpPeer, ev events) {
	buf := make([]byte, 64*1024)
	for {
		n, err := p.conn.Read(buf)
		if err != nil {
			return
		}
		p.touch()
		p.packets.Add(1)
		p.down.Add(int64(n))
		if _, err := listener.WriteTo(buf[:n], addr); err != nil {
			return
		}
	}
}
