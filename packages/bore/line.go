package main

import (
	"fmt"
	"strings"
	"time"

	"charm.land/lipgloss/v2"
)

// Traffic lines are printed one at a time into scrollback, so a column can
// never be resized once it is on screen. Every column therefore has a width
// picked from the widest thing that can ever land in it, and the formatters
// below are written to honour those widths rather than to be pretty in the
// average case.
//
// The subject takes whatever is left, and when there is not enough left the
// columns are dropped from the least useful in: a byte count you can live
// without, a duration you can usually guess, a timestamp you can read off the
// prompt. What survives to the end is the thing that happened and how it went.
const (
	timeWidth    = 8 // 15:04:05
	verbWidth    = 7 // OPTIONS, CONNECT, or a protocol name
	statusWidth  = 3 // 200, ok, err
	tookWidth    = 5 // 999µs … 59.9m
	sizeWidth    = 6 // 999 kB
	subjectFloor = 16
	subjectCeil  = 48 // a wide terminal should not push the numbers to the edge
	subjectPlain = 32 // when there is no terminal to measure
	gap          = "  "
)

// trafficLine is one thing that went through the tunnel, laid out in columns
// shared by requests and flows so a tcp tunnel reads like an http one.
type trafficLine struct {
	at          time.Time
	verb        string
	verbStyle   lipgloss.Style
	subject     string
	status      string
	statusStyle lipgloss.Style
	took        time.Duration
	bytes       int64
}

// render fits the line to the terminal. A width of zero means we are not
// drawing to one, so nothing is dropped.
func (l trafficLine) render(width int) string {
	showTime, showTook, showSize := true, true, true

	// Fixed cost of everything but the subject and its trailing gap.
	fixed := func() int {
		n := verbWidth + len(gap) + statusWidth
		for _, col := range []struct {
			shown bool
			width int
		}{{showTime, timeWidth}, {showTook, tookWidth}, {showSize, sizeWidth}} {
			if col.shown {
				n += col.width + len(gap)
			}
		}
		return n
	}

	subject := subjectPlain
	if width > 0 {
		// Give up columns in order until the subject has room to say anything.
		for _, drop := range []*bool{&showSize, &showTook, &showTime} {
			if width-fixed()-len(gap) >= subjectFloor {
				break
			}
			*drop = false
		}
		// The floor decides when to drop a column, not how narrow the subject
		// may get: past that point the terminal is narrower than the line can
		// be, and running over would wrap every line into two.
		subject = min(max(width-fixed()-len(gap), 0), subjectCeil)
	}

	var out strings.Builder
	if showTime {
		out.WriteString(dim(l.at.Format("15:04:05")) + gap)
	}
	out.WriteString(l.verbStyle.Render(padRight(l.verb, verbWidth)) + gap)
	if subject > 0 {
		out.WriteString(padRight(l.subject, subject) + gap)
	}
	out.WriteString(l.statusStyle.Render(padLeft(l.status, statusWidth)))
	if showTook {
		out.WriteString(gap + dim(padLeft(duration(l.took), tookWidth)))
	}
	if showSize {
		out.WriteString(gap + dim(padLeft(size(l.bytes), sizeWidth)))
	}
	return out.String()
}

// duration fits five columns whatever it is handed. A request is over in
// milliseconds but a tcp conversation can last all afternoon, and both have to
// sit in the same slot. It gives up at a thousand hours, which is six weeks.
func duration(d time.Duration) string {
	switch {
	case d < time.Millisecond:
		return fmt.Sprintf("%dµs", d.Microseconds())
	case d < time.Second:
		return fmt.Sprintf("%dms", d.Milliseconds())
	case d < time.Minute:
		return fmt.Sprintf("%.1fs", d.Seconds())
	case d < time.Hour:
		return fmt.Sprintf("%.1fm", d.Minutes())
	case d < 10*time.Hour:
		return fmt.Sprintf("%.1fh", d.Hours())
	}
	return fmt.Sprintf("%dh", int(d.Hours()))
}

// size fits six columns. The units are SI, so the divisor is 1000: calling
// 1024 bytes a kilobyte was always the other way round, and it is what made
// the old formatter print a ten-column "1023.9 kB" into a nine-column slot.
func size(bytes int64) string {
	units := []string{"B", "kB", "MB", "GB", "TB", "PB", "EB"}
	value, unit := float64(bytes), 0
	for value >= 1000 && unit < len(units)-1 {
		value /= 1000
		unit++
	}
	// A hair under the next unit still rounds up into four digits, so step
	// again rather than let "1000 kB" widen the column.
	if value >= 999.5 && unit < len(units)-1 {
		value /= 1000
		unit++
	}

	switch {
	case unit == 0:
		return fmt.Sprintf("%d B", bytes)
	case value < 10:
		return fmt.Sprintf("%.1f %s", value, units[unit])
	}
	return fmt.Sprintf("%.0f %s", value, units[unit])
}

// padRight keeps a column in the same place whatever is in it, cutting what
// will not fit. It measures printed width rather than bytes, since a µ or an
// arrow is one column and two bytes.
func padRight(s string, width int) string {
	if n := lipgloss.Width(s); n > width {
		return truncate(s, width-1) + "…"
	}
	return s + strings.Repeat(" ", width-lipgloss.Width(s))
}

func padLeft(s string, width int) string {
	if n := lipgloss.Width(s); n < width {
		return strings.Repeat(" ", width-n) + s
	}
	return s
}

func truncate(s string, width int) string {
	var out strings.Builder
	for _, r := range s {
		if lipgloss.Width(out.String()+string(r)) > width {
			break
		}
		out.WriteRune(r)
	}
	return out.String()
}
