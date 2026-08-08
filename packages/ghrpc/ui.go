package main

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"slices"
	"strings"

	"github.com/charmbracelet/huh"
	"github.com/charmbracelet/huh/spinner"
	"github.com/charmbracelet/lipgloss"
	"github.com/charmbracelet/lipgloss/tree"
)

// ANSI 0-15 only, so the terminal's own theme picks the actual colours rather
// than us pinning shades out of the 256-colour cube.
var (
	styleOK     = lipgloss.NewStyle().Foreground(lipgloss.Color("2"))
	styleWarn   = lipgloss.NewStyle().Foreground(lipgloss.Color("3"))
	styleFail   = lipgloss.NewStyle().Foreground(lipgloss.Color("1"))
	styleNote   = lipgloss.NewStyle().Foreground(lipgloss.Color("6"))
	styleHeader = lipgloss.NewStyle().Foreground(lipgloss.Color("4")).Bold(true)
)

// Output shape: a bold title, then left-aligned green labels padded so their
// values line up, then a tree of what was written. No tick marks; the label
// names the thing and the value is what you actually want to read.
const labelWidth = 10

var labelStyle = lipgloss.NewStyle().Foreground(lipgloss.Color("2"))

func title(name, description string) {
	line := lipgloss.NewStyle().Bold(true).Render(name)
	if description != "" {
		line += dimStyle.Render("  " + description)
	}
	fmt.Println(line)
}

// link wraps text in an OSC 8 hyperlink so terminals that support it make the
// URL clickable. Piped output gets the plain URL, since the escapes would just
// be noise in a file.
func link(url, text string) string {
	if !stdoutIsTerminal() {
		return text
	}
	return "\x1b]8;;" + url + "\x1b\\" + text + "\x1b]8;;\x1b\\"
}

// rowLink prints a label against a clickable URL.
func rowLink(label, url string) {
	row(label, "%s", link(url, url))
}

func stdoutIsTerminal() bool {
	info, err := os.Stdout.Stat()
	return err == nil && info.Mode()&os.ModeCharDevice != 0
}

// row prints one label/value pair, padded so values align in a column.
func row(label, format string, a ...any) {
	fmt.Printf("%s  %s\n", pad(labelStyle, label), fmt.Sprintf(format, a...))
}

// rowGroup prints label/value pairs aligned to their own widest label, for
// blocks whose labels do not fit the standard column.
func rowGroup(pairs [][2]string) {
	width := labelWidth
	for _, pair := range pairs {
		width = max(width, lipgloss.Width(pair[0]))
	}
	for _, pair := range pairs {
		gap := strings.Repeat(" ", width-lipgloss.Width(pair[0]))
		fmt.Printf("%s%s  %s\n", labelStyle.Render(pair[0]), gap, pair[1])
	}
}

// pad renders a label at labelWidth. The padding goes outside the style so a
// styled label and a plain one still line up.
func pad(style lipgloss.Style, label string) string {
	if width := labelWidth - lipgloss.Width(label); width > 0 {
		return style.Render(label) + strings.Repeat(" ", width)
	}
	return style.Render(label)
}

// rowDim prints a pair whose value is not news, like a remote that was
// already pointing where we wanted it.
func rowDim(label, format string, a ...any) {
	row(label, "%s", dimStyle.Render(fmt.Sprintf(format, a...)))
}

func warn(format string, a ...any) {
	fmt.Println(pad(styleWarn, "warning") + "  " + fmt.Sprintf(format, a...))
}

func failure(format string, a ...any) {
	fmt.Println(pad(styleFail, "error") + "  " + fmt.Sprintf(format, a...))
}

// step runs a slow action behind a spinner, so the terminal is not silent
// while we wait on the network. Without a terminal it just runs the action.
func step(title string, action func()) {
	if !stdoutIsTerminal() {
		action()
		return
	}
	_ = spinner.New().
		Type(spinner.Dots).
		Title(" " + title).
		TitleStyle(dimStyle).
		Style(labelStyle).
		Action(action).
		Run()
}

func fatal(format string, a ...any) {
	failure(format, a...)
	os.Exit(1)
}

// fileTree renders the paths that were written as a directory tree, so the
// shape of the new repo is visible at a glance.
func fileTree(root string, paths []string) string {
	t := tree.Root(lipgloss.NewStyle().Bold(true).Render(root))
	nodes := map[string]*tree.Tree{}

	// Walk each path, creating the branches it needs on the way down.
	for _, path := range slices.Sorted(slices.Values(paths)) {
		parent, prefix := t, ""
		segments := strings.Split(path, "/")
		for _, dir := range segments[:len(segments)-1] {
			prefix = filepath.Join(prefix, dir)
			branch, built := nodes[prefix]
			if !built {
				branch = tree.Root(dir + "/")
				nodes[prefix] = branch
				parent.Child(branch)
			}
			parent = branch
		}
		parent.Child(segments[len(segments)-1])
	}

	return t.
		Enumerator(tree.RoundedEnumerator).
		EnumeratorStyle(dimStyle.PaddingRight(1)).
		ItemStyleFunc(func(children tree.Children, i int) lipgloss.Style {
			// Directories carry their own children; tint them so the shape of
			// the repo reads before the individual files do.
			if child := children.At(i); child != nil && child.Children().Length() > 0 {
				return lipgloss.NewStyle().Foreground(lipgloss.Color("6"))
			}
			return lipgloss.NewStyle()
		}).
		String()
}

// abort ends the run when the user hits ctrl-c inside a form: no message, and
// the conventional 128+SIGINT status.
func abort(err error) {
	if errors.Is(err, huh.ErrUserAborted) {
		os.Exit(130)
	}
	fatal("%v", err)
}

// dimStyle is the comment colour: bright black, so it recedes in any theme.
var dimStyle = lipgloss.NewStyle().Foreground(lipgloss.Color("8"))

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
