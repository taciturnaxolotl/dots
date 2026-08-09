package main

import (
	"errors"
	"fmt"
	"os"
	"strings"

	"github.com/charmbracelet/huh"
	"github.com/charmbracelet/lipgloss"
)

// ANSI 0-15 only, so the terminal's own theme picks the shades.
var (
	labelStyle = lipgloss.NewStyle().Foreground(lipgloss.Color("2"))
	failStyle  = lipgloss.NewStyle().Foreground(lipgloss.Color("1"))
	warnStyle  = lipgloss.NewStyle().Foreground(lipgloss.Color("3"))
	dimStyle   = lipgloss.NewStyle().Foreground(lipgloss.Color("8"))
)

// A section is a run of label/value lines aligned to their widest label.
type section struct{ width int }

func newSection(labels ...string) *section {
	s := &section{}
	for _, label := range labels {
		s.width = max(s.width, lipgloss.Width(label))
	}
	return s
}

func (s *section) row(label, value string)  { s.line(labelStyle, label, value) }
func (s *section) fail(label, value string) { s.line(failStyle, label, value) }
func (s *section) warn(label, value string) { s.line(warnStyle, label, value) }

func (s *section) line(style lipgloss.Style, label, value string) {
	gap := ""
	if n := s.width - lipgloss.Width(label); n > 0 {
		gap = strings.Repeat(" ", n)
	}
	fmt.Println(style.Render(label) + gap + "  " + value)
}

func dim(text string) string { return dimStyle.Render(text) }

// link makes a URL clickable where the terminal supports it.
func link(url string) string {
	if !stdoutIsTerminal() {
		return url
	}
	return "\x1b]8;;" + url + "\x1b\\" + url + "\x1b]8;;\x1b\\"
}

func stdoutIsTerminal() bool {
	info, err := os.Stdout.Stat()
	return err == nil && info.Mode()&os.ModeCharDevice != 0
}

// interactiveSession reports whether a form can be drawn: huh reads the
// controlling terminal, so /dev/tty is the real test.
func interactiveSession() bool {
	tty, err := os.OpenFile("/dev/tty", os.O_RDWR, 0)
	if err != nil {
		return false
	}
	tty.Close()
	info, err := os.Stdin.Stat()
	return err == nil && info.Mode()&os.ModeCharDevice != 0
}

// abort ends the run when the user hits ctrl-c inside a form.
func abort(err error) {
	if errors.Is(err, huh.ErrUserAborted) {
		os.Exit(130)
	}
	fmt.Fprintln(os.Stderr, err)
	os.Exit(1)
}

func formTheme() *huh.Theme {
	t := huh.ThemeBase16()

	plain := lipgloss.NewStyle()
	t.Focused.Base, t.Blurred.Base = plain, plain
	t.Focused.Card, t.Blurred.Card = plain, plain

	// Unfocused fields keep their normal colour. Base16 greys the title and
	// prompt of every field but the current one, which leaves a form of five
	// questions looking like one live line and four dead ones. The cursor and
	// the accent on the focused title already say where you are.
	plainText := lipgloss.NewStyle()
	t.Blurred.Title = plainText
	t.Blurred.NoteTitle = plainText
	t.Blurred.TextInput.Prompt = plainText
	t.Blurred.TextInput.Text = plainText

	key := lipgloss.NewStyle().Foreground(lipgloss.Color("7"))
	t.Help.ShortKey, t.Help.FullKey = key, key
	t.Help.ShortDesc, t.Help.FullDesc = dimStyle, dimStyle
	t.Help.ShortSeparator, t.Help.FullSeparator = dimStyle, dimStyle
	t.Help.Ellipsis = dimStyle

	return t
}

// selectField builds a picker with no explicit height, so the cursor moves
// through the list instead of the list scrolling under it.
func selectField[T comparable](options []huh.Option[T], value *T) *huh.Select[T] {
	return huh.NewSelect[T]().Options(options...).Value(value)
}

// yesNo asks a yes/no question as a two-item list, matching every other prompt.
func yesNo(title string, value *bool) *huh.Select[bool] {
	return selectField([]huh.Option[bool]{
		huh.NewOption("no", false),
		huh.NewOption("yes", true),
	}, value).Title(title)
}
