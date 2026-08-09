package main

import (
	"context"
	"fmt"
	"os"
	"strings"
	"time"

	tea "charm.land/bubbletea/v2"
	"charm.land/huh/v2"
	"charm.land/lipgloss/v2"
)

// tunnelOptions is what the command line asked for. The *Given fields record
// which flags were actually passed, so the form only asks about the rest.
type tunnelOptions struct {
	name     string
	port     int
	protocol string
	labels   []string
	auth     bool
	save     bool

	protocolGiven bool
	labelsGiven   bool
	authGiven     bool
	verbose       bool
	noInspect     bool
}

func runTunnel(ctx context.Context, opts tunnelOptions) error {
	cfg, err := LoadConfig()
	if err != nil {
		return err
	}

	t, err := resolve(cfg, opts)
	if err != nil {
		return err
	}
	if err := validate(t); err != nil {
		return err
	}

	if opts.save {
		if err := cfg.Save(t); err != nil {
			return fmt.Errorf("could not write %s: %w", ConfigFile, err)
		}
	}

	return start(ctx, t, opts)
}

// resolve settles what tunnel to open: the command line first, then a saved
// entry of the same name, then the form for whatever is still missing.
func resolve(cfg *Config, opts tunnelOptions) (*Tunnel, error) {
	t := &Tunnel{
		Name:     opts.name,
		Port:     opts.port,
		Protocol: opts.protocol,
		Labels:   opts.labels,
		Auth:     opts.auth,
	}

	// A bare name that matches a saved tunnel means "run that one".
	if saved, ok := cfg.Tunnels[t.Name]; ok {
		if t.Port == 0 {
			t.Port = saved.Port
		}
		if !opts.protocolGiven {
			t.Protocol = saved.Protocol
		}
		if !opts.labelsGiven {
			t.Labels = saved.Labels
		}
		if !opts.authGiven {
			t.Auth = saved.Auth
		}
		return t, nil
	}

	if t.Name != "" && t.Port != 0 {
		return t, nil
	}
	if !interactiveSession() {
		return nil, fmt.Errorf("a tunnel needs a name and a port")
	}
	return ask(cfg, t, opts)
}

// ask fills in the gaps. Choosing a saved tunnel takes its settings whole,
// since that is the point of having saved it.
func ask(cfg *Config, t *Tunnel, opts tunnelOptions) (*Tunnel, error) {
	if t.Name == "" && len(cfg.Names()) > 0 {
		const newTunnel = "a new tunnel"
		choice := newTunnel

		options := append([]string{newTunnel}, cfg.Names()...)
		form := huh.NewForm(huh.NewGroup(
			selectField(huh.NewOptions(options...), &choice).Title("Tunnel"),
		)).WithTheme(formTheme)
		if err := form.Run(); err != nil {
			abort(err)
		}
		if saved, ok := cfg.Tunnels[choice]; ok {
			return saved, nil
		}
	}

	// One question per group. huh collects a group's validation errors into a
	// footer, so with everything in one group "invalid port" appeared under
	// the last question instead of under the port.
	var groups []*huh.Group

	if !opts.protocolGiven && t.Protocol == "" {
		t.Protocol = "http"
		groups = append(groups, huh.NewGroup(
			selectField(huh.NewOptions(protocols...), &t.Protocol).Title("Protocol"),
		))
	}
	if t.Name == "" {
		groups = append(groups, huh.NewGroup(huh.NewInput().
			Title("Name").
			DescriptionFunc(func() string { return nameHint(t.protocolOrDefault()) }, &t.Protocol).
			Placeholder("myapp").
			Validate(func(s string) error { return checkName(s, t.protocolOrDefault()) }).
			Value(&t.Name)))
	}

	port := ""
	if t.Port != 0 {
		port = fmt.Sprint(t.Port)
	}
	if t.Port == 0 {
		groups = append(groups, huh.NewGroup(huh.NewInput().
			Title("Local port").
			Description("the port your service is already running on").
			Placeholder("8000").
			Validate(checkPort).
			Value(&port)))
	}

	labels := ""
	if !opts.labelsGiven && len(t.Labels) == 0 {
		groups = append(groups, huh.NewGroup(huh.NewInput().
			Title("Labels").
			Description("comma separated, optional").
			Placeholder("dev").
			Value(&labels)))
	}
	if !opts.authGiven {
		groups = append(groups, huh.NewGroup(yesNo("Require Indiko sign-in?", &t.Auth)))
	}

	if len(groups) > 0 {
		if err := huh.NewForm(groups...).WithTheme(formTheme).Run(); err != nil {
			abort(err)
		}
	}
	t.Labels = append(t.Labels, splitLabels(labels)...)

	if t.Port == 0 {
		parsed, err := parsePort(port)
		if err != nil {
			return nil, err
		}
		t.Port = parsed
	}
	return t, nil
}

// The validators speak to the person typing. huh puts whatever they return
// straight on screen, so "invalid port \"\"" is a message to nobody.

func checkPort(s string) error {
	switch {
	case strings.TrimSpace(s) == "":
		return fmt.Errorf("which port is your service on?")
	case !allDigits(s):
		return fmt.Errorf("a port is a number, like 8000")
	}
	if _, err := parsePort(s); err != nil {
		return fmt.Errorf("ports go from 1 to 65535")
	}
	return nil
}

func checkName(s, protocol string) error {
	switch {
	case strings.TrimSpace(s) == "":
		return fmt.Errorf("what should this tunnel be called?")
	case protocol == "http" && !validSubdomain.MatchString(s):
		return fmt.Errorf("a subdomain can hold lowercase letters, numbers and hyphens")
	}
	return nil
}

// nameHint says what the name is for, which depends on the protocol.
func nameHint(protocol string) string {
	if protocol == "http" {
		return "the subdomain: NAME." + domain
	}
	return "a name for this tunnel"
}

func allDigits(s string) bool {
	for _, r := range s {
		if r < '0' || r > '9' {
			return false
		}
	}
	return s != ""
}

func validate(t *Tunnel) error {
	if t.Name == "" {
		return fmt.Errorf("a tunnel needs a name")
	}
	if t.protocolOrDefault() == "http" && !validSubdomain.MatchString(t.Name) {
		return fmt.Errorf("invalid subdomain %q: use lowercase letters, numbers and hyphens", t.Name)
	}
	if t.Port < 1 || t.Port > 65535 {
		return fmt.Errorf("invalid port %d", t.Port)
	}
	if !contains(protocols, t.protocolOrDefault()) {
		return fmt.Errorf("invalid protocol %q: use %s", t.Protocol, listOr(protocols))
	}
	return nil
}

// events is everything an inspector or frpc has to say, in the one shape both
// the live view and the plain printer can take.
type events struct {
	request func(request)
	flow    func(flow)
	notice  func(notice)
	// header adds a detail that only becomes known once the tunnel is up.
	header func(headerRow)
	// open counts conversations in flight: +1 on connect, -1 on close.
	open func(int)
}

// interpose puts a counter in front of the local port, whatever it speaks, and
// returns the port frpc should use instead.
func interpose(protocol string, target int, ev events) (int, error) {
	if protocol == "http" {
		in, err := startInspector(target, ev)
		if err != nil {
			return 0, err
		}
		return in.port, nil
	}
	return startStream(protocol, target, ev)
}

// carries names what a tunnel moves, for counting it out loud.
func carries(protocol string) string {
	switch protocol {
	case "tcp":
		return "connections"
	case "udp":
		return "callers"
	}
	return "requests"
}

// start writes the frpc config and runs it, either under the full screen view
// or as plain lines when there is no terminal to draw on.
func start(root context.Context, t *Tunnel, opts tunnelOptions) error {
	adminPort := 0
	if t.protocolOrDefault() != "http" {
		port, err := freePort()
		if err != nil {
			return err
		}
		adminPort = port
	}

	rows := headerRows(t, opts)
	sec := newSection("protocol", "public", "local", "labels", "auth", "saved")

	// Under the live view, everything that happens becomes a message. Plain
	// mode prints it as it happens.
	live := !opts.noInspect && !opts.verbose && stdoutIsTerminal()

	var program *tea.Program
	ev := events{
		request: func(r request) { lipgloss.Println(r.render()) },
		flow:    func(f flow) { lipgloss.Println(f.render()) },
		notice:  sec.notice,
		header:  func(row headerRow) { sec.row(row.label, row.value) },
		open:    func(int) {},
	}
	if live {
		program = tea.NewProgram(tunnelUI{
			header:  rows,
			noun:    carries(t.protocolOrDefault()),
			started: time.Now(),
		})
		ev = events{
			request: func(r request) { program.Send(requestMsg(r)) },
			flow:    func(f flow) { program.Send(flowMsg(f)) },
			notice:  func(n notice) { program.Send(noticeMsg(n)) },
			header:  func(row headerRow) { program.Send(headerMsg(row)) },
			open:    func(delta int) { program.Send(openMsg(delta)) },
		}
	}

	// frpc is pointed at an inspector rather than at the service, so everything
	// going through passes something that can count it.
	localPort := t.Port
	if !opts.noInspect {
		port, err := interpose(t.protocolOrDefault(), t.Port, ev)
		if err != nil {
			return err
		}
		localPort = port
	}

	path, err := writeConfig(buildConfig(t, localPort, adminPort, opts.verbose))
	if err != nil {
		return err
	}
	defer os.Remove(path)

	// frpc must not outlive us, whether we are closed by the view, by ctrl-c
	// or by a TERM from something else. Hanging tunnels are worse than no
	// tunnels: they keep serving from a bore that is no longer watching.
	ctx, stop := context.WithCancel(root)
	defer stop()

	if !live {
		for _, row := range rows {
			sec.row(row.label, row.value)
		}
		// A udp socket does not answer a tcp dial, so there is nothing to
		// usefully probe there.
		if t.protocolOrDefault() != "udp" && !listening(t.Port) {
			sec.warn("local", fmt.Sprintf("nothing is listening on localhost:%d", t.Port))
		}
		fmt.Println()
		return run(ctx, t, path, adminPort, opts.verbose, ev)
	}

	go func() {
		err := run(ctx, t, path, adminPort, opts.verbose, ev)
		program.Send(doneMsg{err})
	}()

	_, err = program.Run()
	stop()
	return err
}

// headerRows are the tunnel's details, which stay on screen while it runs.
func headerRows(t *Tunnel, opts tunnelOptions) []headerRow {
	rows := []headerRow{
		{"name", t.Name},
		{"local", fmt.Sprintf("localhost:%d", t.Port)},
	}
	if t.protocolOrDefault() == "http" {
		rows = append(rows, headerRow{"public", link("https://" + t.Name + "." + domain)})
	} else {
		rows = append(rows, headerRow{"protocol", t.protocolOrDefault()})
	}
	if labels := t.LabelString(); labels != "" {
		rows = append(rows, headerRow{"labels", labels})
	}
	if t.Auth {
		rows = append(rows, headerRow{"auth", "Indiko sign-in required"})
	}
	if opts.save {
		rows = append(rows, headerRow{"saved", ConfigFile})
	}
	return rows
}

func contains(list []string, want string) bool {
	for _, v := range list {
		if v == want {
			return true
		}
	}
	return false
}
