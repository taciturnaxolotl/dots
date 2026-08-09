package main

import (
	"strings"
	"testing"
	"time"

	"charm.land/lipgloss/v2"
)

// The columns are only in the same place on every line if nothing can ever
// overflow its slot, and both formatters have inputs that used to.
func TestDurationNeverOutgrowsItsColumn(t *testing.T) {
	for _, d := range []time.Duration{
		0,
		999 * time.Microsecond,
		time.Millisecond,
		999 * time.Millisecond,
		59*time.Second + 990*time.Millisecond,
		time.Minute,
		59*time.Minute + 59*time.Second,
		time.Hour,
		9*time.Hour + 59*time.Minute,
		36 * time.Hour,
		200 * time.Hour,
	} {
		if got := duration(d); lipgloss.Width(got) > tookWidth {
			t.Errorf("duration(%s) = %q, %d wide, want at most %d", d, got, lipgloss.Width(got), tookWidth)
		}
	}
}

func TestSizeNeverOutgrowsItsColumn(t *testing.T) {
	for _, b := range []int64{
		0, 1, 999, 1000, 1023, 999_499, 999_500, 1_000_000,
		999_999_999, 1 << 40, 1 << 50, 1<<63 - 1,
	} {
		if got := size(b); lipgloss.Width(got) > sizeWidth {
			t.Errorf("size(%d) = %q, %d wide, want at most %d", b, got, lipgloss.Width(got), sizeWidth)
		}
	}
}

func TestSizeCountsInThousands(t *testing.T) {
	// The units say kB, not KiB, so the divisor has to match what is written.
	for _, c := range []struct {
		bytes int64
		want  string
	}{
		{999, "999 B"},
		{1000, "1.0 kB"},
		{829, "829 B"},
		{1_200_000, "1.2 MB"},
	} {
		if got := size(c.bytes); got != c.want {
			t.Errorf("size(%d) = %q, want %q", c.bytes, got, c.want)
		}
	}
}

// A line has to fit the terminal it is printed into, whatever is in it.
func TestTrafficLineFitsTheTerminal(t *testing.T) {
	line := trafficLine{
		at:          time.Now(),
		verb:        "OPTIONS",
		verbStyle:   lipgloss.NewStyle(),
		subject:     strings.Repeat("/very-long-path", 20),
		status:      "200",
		statusStyle: lipgloss.NewStyle(),
		took:        90 * time.Minute,
		bytes:       1<<62 - 1,
	}
	// Narrower than the verb and status columns is not a terminal anyone has.
	for width := verbWidth + len(gap) + statusWidth; width <= 200; width++ {
		if got := lipgloss.Width(line.render(width)); got > width {
			t.Fatalf("a %d wide terminal got a %d wide line", width, got)
		}
	}
}

// Narrow terminals give up columns rather than the subject, in order of what
// can most be done without.
func TestNarrowLinesDropColumnsInOrder(t *testing.T) {
	line := trafficLine{
		at:          time.Date(2026, 8, 8, 21, 34, 28, 0, time.UTC),
		verb:        "GET",
		verbStyle:   lipgloss.NewStyle(),
		subject:     "/api/models/chat",
		status:      "200",
		statusStyle: lipgloss.NewStyle(),
		took:        886 * time.Microsecond,
		bytes:       829,
	}

	full := line.render(100)
	for _, want := range []string{"21:34:28", "886µs", "829 B", "/api/models/chat"} {
		if !strings.Contains(full, want) {
			t.Errorf("a wide terminal should show %q: %q", want, full)
		}
	}

	if got := line.render(47); strings.Contains(got, "829 B") || !strings.Contains(got, "886µs") {
		t.Errorf("the byte count should go before the duration: %q", got)
	}
	if got := line.render(42); strings.Contains(got, "886µs") || !strings.Contains(got, "21:34:28") {
		t.Errorf("the duration should go before the time: %q", got)
	}
	if got := line.render(30); strings.Contains(got, "21:34:28") {
		t.Errorf("the time should go last: %q", got)
	}
	// Whatever else goes, what happened and how it went stay.
	narrow := line.render(30)
	for _, want := range []string{"GET", "200", "/api"} {
		if !strings.Contains(narrow, want) {
			t.Errorf("the narrowest line should still show %q: %q", want, narrow)
		}
	}
}

// A µ is two bytes and one column, and the subject can hold arrows.
func TestPaddingMeasuresColumnsNotBytes(t *testing.T) {
	if got := lipgloss.Width(padRight("↑ 85 B  ↓ 1.1 kB", 20)); got != 20 {
		t.Errorf("padRight produced %d columns, want 20", got)
	}
	if got := lipgloss.Width(padRight("↑ 85 B  ↓ 1.1 kB", 10)); got != 10 {
		t.Errorf("truncation produced %d columns, want 10", got)
	}
	if got := lipgloss.Width(padLeft("886µs", tookWidth)); got != tookWidth {
		t.Errorf("padLeft produced %d columns, want %d", got, tookWidth)
	}
}
