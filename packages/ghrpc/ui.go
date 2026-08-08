package main

import (
	"errors"
	"fmt"
	"os"
	"strings"

	"github.com/charmbracelet/huh"
	"github.com/charmbracelet/huh/spinner"
	"github.com/charmbracelet/lipgloss"
)

// ANSI 0-15 only, so the terminal's own theme picks the actual colours rather
// than us pinning shades out of the 256-colour cube.
var (
	labelStyle = lipgloss.NewStyle().Foreground(lipgloss.Color("2"))
	failStyle  = lipgloss.NewStyle().Foreground(lipgloss.Color("1"))
	dimStyle   = lipgloss.NewStyle().Foreground(lipgloss.Color("8"))
	dirStyle   = lipgloss.NewStyle().Foreground(lipgloss.Color("4"))
	proseStyle = lipgloss.NewStyle().Foreground(lipgloss.Color("3"))
)

// A section is a run of label/value lines that align with each other. Each one
// sizes its own column, so a long label in the summary does not push the lines
// at the top of the output out to meet it.
//
// Every line is a label and a value, including the ones reporting a problem:
// the label names the subject (a remote, a file, a forge) and turns red, so
// there is no separate "warning" column drifting out of alignment.
type section struct{ width int }

// newSection sizes a column to the longest label it may print.
func newSection(labels ...string) *section {
	s := &section{}
	for _, label := range labels {
		s.width = max(s.width, lipgloss.Width(label))
	}
	return s
}

// row prints a label against its value.
func (s *section) row(label, value string) {
	s.line(labelStyle, label, value)
}

// fail prints a row whose subject went wrong: the label turns red and the
// value carries the reason instead of the result.
func (s *section) fail(label, value string) {
	s.line(failStyle, label, value)
}

func (s *section) line(style lipgloss.Style, label, value string) {
	// The padding sits outside the style so a red label and a green one still
	// line up.
	gap := ""
	if n := s.width - lipgloss.Width(label); n > 0 {
		gap = strings.Repeat(" ", n)
	}
	fmt.Println(style.Render(label) + gap + "  " + value)
}

// step runs a slow action behind a spinner sitting in this section's label
// column, so the text starts where the values do. Without a terminal it just
// runs the action.
func (s *section) step(title string, action func()) {
	if !stdoutIsTerminal() {
		action()
		return
	}
	_ = spinner.New().
		Type(spinner.Dots).
		Title(strings.Repeat(" ", s.width) + title).
		TitleStyle(lipgloss.NewStyle()).
		Style(labelStyle).
		Action(action).
		Run()
}

func dim(text string) string { return dimStyle.Render(text) }

// link wraps a URL in an OSC 8 hyperlink so terminals that support it make it
// clickable. Piped output gets the plain URL, since the escapes would just be
// noise in a file.
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

// abort ends the run when the user hits ctrl-c inside a form: no message, and
// the conventional 128+SIGINT status.
func abort(err error) {
	if errors.Is(err, huh.ErrUserAborted) {
		os.Exit(130)
	}
	fmt.Fprintln(os.Stderr, err)
	os.Exit(1)
}

// formTheme is ThemeBase16 with three fixes: everything on ANSI 0-15 (bubbles
// ships truecolour greys in the help line), no left gutter, and no coloured
// button chrome.
func formTheme() *huh.Theme {
	t := huh.ThemeBase16()

	// No border and no padding: the form starts at column zero, flush with
	// everything else the command prints.
	plain := lipgloss.NewStyle()
	t.Focused.Base, t.Blurred.Base = plain, plain
	t.Focused.Card, t.Blurred.Card = plain, plain

	key := lipgloss.NewStyle().Foreground(lipgloss.Color("7"))
	t.Help.ShortKey, t.Help.FullKey = key, key
	t.Help.ShortDesc, t.Help.FullDesc = dimStyle, dimStyle
	t.Help.ShortSeparator, t.Help.FullSeparator = dimStyle, dimStyle
	t.Help.Ellipsis = dimStyle

	return t
}

// selectField builds a picker with no explicit height, which huh reads as
// "size the viewport to the options" so the cursor moves through the list
// instead of the list scrolling under the cursor.
func selectField[T comparable](options []huh.Option[T], value *T) *huh.Select[T] {
	return huh.NewSelect[T]().Options(options...).Value(value)
}

// yesNo asks a yes/no question as a two-item list, matching every other
// prompt instead of huh's centred button pair.
func yesNo(title, description string, value *bool) *huh.Select[bool] {
	field := selectField([]huh.Option[bool]{
		huh.NewOption("no", false),
		huh.NewOption("yes", true),
	}, value).Title(title)
	if description != "" {
		field = field.Description(description)
	}
	return field
}

func confirm(title string) bool {
	var answer bool
	form := huh.NewForm(huh.NewGroup(yesNo(title, "", &answer))).WithTheme(formTheme())
	if err := form.Run(); err != nil {
		abort(err)
	}
	return answer
}
