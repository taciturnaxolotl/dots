package main

import (
	"fmt"
	"slices"
	"strings"
	"time"

	tea "charm.land/bubbletea/v2"
	"charm.land/lipgloss/v2"
)

// The tunnel's details belong on screen the whole time it is running, but not
// at the cost of the terminal. So this renders inline rather than taking the
// alt screen: request lines are printed above the view and scroll into normal
// scrollback, and only the status block at the bottom is redrawn.
//
// That means you can scroll back through a session afterwards, and whatever
// was in the terminal before is still there.
type tunnelUI struct {
	header []headerRow
	notes  []notice
	// noun is what this tunnel carries: requests over http, connections over
	// tcp, callers over udp. Counting them all as "requests" would be a small
	// lie that makes a tcp tunnel read like an http one.
	noun     string
	width    int
	count    int
	open     int
	bytes    int64
	started  time.Time
	quitting bool
}

type headerRow struct {
	label string
	value string
}

type (
	requestMsg request
	flowMsg    flow
	noticeMsg  notice
	// headerMsg adds or replaces a detail. The server does not hand out a tcp
	// or udp port until the tunnel is up, so that row arrives late.
	headerMsg headerRow
	// openMsg counts conversations in flight: +1 on connect, -1 on close.
	openMsg int
	doneMsg struct{ err error }
)

func (m tunnelUI) Init() tea.Cmd { return nil }

func (m tunnelUI) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		// Lines are printed into scrollback and never redrawn, so the width
		// matters at the moment each one is rendered, not at the end.
		m.width = msg.Width

	case tea.KeyPressMsg:
		switch msg.String() {
		case "ctrl+c", "q", "esc":
			m.quitting = true
			return m, tea.Quit
		}

	case requestMsg:
		m.count++
		m.bytes += msg.bytes
		// Printed rather than stored: the terminal keeps the history.
		return m, tea.Println(request(msg).render(m.width))

	case flowMsg:
		m.count++
		m.bytes += msg.up + msg.down
		return m, tea.Println(flow(msg).render(m.width))

	case openMsg:
		m.open += int(msg)

	case headerMsg:
		row := headerRow(msg)
		if i := slices.IndexFunc(m.header, func(o headerRow) bool { return o.label == row.label }); i >= 0 {
			m.header[i] = row
			break
		}
		m.header = append(m.header, row)

	case noticeMsg:
		n := notice(msg)
		n.after = m.count
		// Drop what this one supersedes: anything about the same subject, and
		// anything a request has already answered for. A dev server restarting
		// twice should not push the tunnel's details off the screen.
		m.notes = slices.DeleteFunc(m.notes, func(o notice) bool {
			return o.label == n.label || o.stale(m.count)
		})
		m.notes = append(m.notes, n)
		if len(m.notes) > 3 {
			m.notes = m.notes[len(m.notes)-3:]
		}

	case doneMsg:
		m.quitting = true
		return m, tea.Quit
	}
	return m, nil
}

func (m tunnelUI) View() tea.View {
	if m.quitting {
		// Leave the details behind rather than clearing them away.
		return tea.NewView(m.status() + "\n")
	}
	return tea.NewView(m.status())
}

func (m tunnelUI) status() string {
	var out strings.Builder

	// Divide the requests scrolling past from the details that stay put.
	out.WriteString("\n")

	width := 0
	for _, row := range m.header {
		width = max(width, lipgloss.Width(row.label))
	}
	for _, row := range m.header {
		gap := strings.Repeat(" ", width-lipgloss.Width(row.label))
		out.WriteString(labelStyle.Render(row.label) + gap + "  " + row.value + "\n")
	}
	for _, n := range m.notes {
		if n.stale(m.count) {
			continue
		}
		gap := strings.Repeat(" ", max(width-lipgloss.Width(n.label), 0))
		out.WriteString(n.style().Render(n.label) + gap + "  " + n.text + "\n")
	}

	// A tunnel is either holding conversations open, has finished some, or is
	// waiting. Saying "waiting for callers" with one on the line was a small
	// untruth. http rarely holds anything open long enough to show.
	var parts []string
	if m.open > 0 {
		parts = append(parts, fmt.Sprintf("%d open", m.open))
	}
	switch {
	case m.count > 0:
		parts = append(parts, plural(m.count, m.noun)+" · "+size(m.bytes))
	case m.open == 0:
		parts = append(parts, "waiting for "+m.noun)
	}
	parts = append(parts, "q to close the tunnel")
	out.WriteString(dim(strings.Join(parts, " · ")))
	return out.String()
}
