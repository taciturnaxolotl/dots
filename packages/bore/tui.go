package main

import (
	"fmt"
	"strings"
	"time"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
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
	notes    []string
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
	noteMsg    struct{ label, text string }
	doneMsg    struct{ err error }
)

func (m tunnelUI) Init() tea.Cmd { return nil }

func (m tunnelUI) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
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

	case noteMsg:
		m.notes = append(m.notes, failStyle.Render(msg.label)+"  "+msg.text)
		if len(m.notes) > 2 {
			m.notes = m.notes[len(m.notes)-2:]
		}

	case doneMsg:
		m.quitting = true
		return m, tea.Quit
	}
	return m, nil
}

func (m tunnelUI) View() string {
	if m.quitting {
		// Leave the details behind rather than clearing them away.
		return m.status() + "\n"
	}
	return m.status()
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
	for _, note := range m.notes {
		out.WriteString(note + "\n")
	}

	summary := "waiting for requests"
	if m.count > 0 {
		summary = fmt.Sprintf("%d requests · %s", m.count, size(m.bytes))
	}
	out.WriteString(dim(summary + " · q to close the tunnel"))
	return out.String()
}
