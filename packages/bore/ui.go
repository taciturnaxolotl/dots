package main

import (
	"errors"
	"fmt"
	"os"
	"strings"

	"charm.land/huh/v2"
	"charm.land/lipgloss/v2"
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

// A notice is something that happened to the tunnel rather than through it.
//
// Warnings are moments: a response cut short, a dial that failed. Errors are
// states: the tunnel is not working, and saying so once and vanishing would be
// worse than useless.
type notice struct {
	label string
	text  string
	fatal bool
	// after is how many requests had been served when this happened. A warning
	// is the latest news until a request goes through, which is both the proof
	// that it has passed and the only clock that means anything here: a tunnel
	// nobody is using should still say why the last try failed.
	after int
}

// stale reports whether a request has arrived since, making this old news.
func (n notice) stale(requests int) bool { return !n.fatal && requests > n.after }

// style is red when the tunnel is broken and yellow when it is merely a bad
// moment, matching what fail and warn mean in a section.
func (n notice) style() lipgloss.Style {
	if n.fatal {
		return failStyle
	}
	return warnStyle
}

// notice prints one in this section's column, so it lines up with the tunnel's
// details rather than starting wherever its label happens to end.
func (s *section) notice(n notice) { s.line(n.style(), n.label, n.text) }

func (s *section) row(label, value string)  { s.line(labelStyle, label, value) }
func (s *section) fail(label, value string) { s.line(failStyle, label, value) }
func (s *section) warn(label, value string) { s.line(warnStyle, label, value) }

func (s *section) line(style lipgloss.Style, label, value string) {
	gap := ""
	if n := s.width - lipgloss.Width(label); n > 0 {
		gap = strings.Repeat(" ", n)
	}
	// lipgloss.Println rather than fmt: v2 dropped the renderer that noticed
	// it was not writing to a terminal, so styled text has to go through
	// something that downsamples, or piped output fills with escapes.
	lipgloss.Println(style.Render(label) + gap + "  " + value)
}

func dim(text string) string { return dimStyle.Render(text) }

// plural counts a noun without a table of exceptions, which works because
// every noun a tunnel carries is regular.
func plural(n int, noun string) string {
	if n == 1 {
		return "1 " + strings.TrimSuffix(noun, "s")
	}
	return fmt.Sprintf("%d %s", n, noun)
}

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

var formTheme = huh.ThemeFunc(func(isDark bool) *huh.Styles {
	t := huh.ThemeBase16(isDark)

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
})

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
