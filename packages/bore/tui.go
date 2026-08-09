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
	header   []headerRow
	notes    []notice
	count    int
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
	noticeMsg  notice
	doneMsg    struct{ err error }
)

func (m tunnelUI) Init() tea.Cmd { return nil }

func (m tunnelUI) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
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
		return m, tea.Println(request(msg).render())

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

	summary := "waiting for requests"
	if m.count > 0 {
		summary = fmt.Sprintf("%d requests · %s", m.count, size(m.bytes))
	}
	out.WriteString(dim(summary + " · q to close the tunnel"))
	return out.String()
}
