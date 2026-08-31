package cli

import (
	"fmt"
	"os"
	"strings"

	"charm.land/bubbles/v2/table"
	"charm.land/lipgloss/v2"
	"golang.org/x/term"
)

// statusTableEnabled keeps redirected reports and NO_COLOR output stable for
// scripts while giving an interactive terminal a denser component inventory.
func statusTableEnabled() bool {
	if os.Getenv("NO_COLOR") != "" || os.Getenv("TERM") == "dumb" {
		return false
	}
	return term.IsTerminal(int(os.Stdout.Fd()))
}

// terminalText renders the status inventory with Bubble Tea's table component.
// It intentionally has no interactive input loop: status is a snapshot that
// must complete cleanly for callers that invoke it from a terminal pipeline.
func (r statusReport) terminalText(kitDir string) string {
	var b strings.Builder
	fmt.Fprintln(&b, titleStyle.Render("✦ Airgap Status"))
	fmt.Fprintln(&b, dimStyle.Render("Offline kit and installed component inventory"))
	fmt.Fprintln(&b, accentStyle.Render("────────────────────────────────"))
	fmt.Fprintln(&b, statusSummary("Kit", kitDir))
	fmt.Fprintln(&b, statusSummary("Target", r.Target))
	if r.RecordFound {
		fmt.Fprintln(&b, statusSummary("Installed", r.Version+" from "+r.InstalledFrom))
	} else {
		fmt.Fprintln(&b, statusSummary("Installed", "not recorded; run airgap install"))
	}

	if len(r.Components) > 0 {
		fmt.Fprintln(&b, accentStyle.Render("Recorded components"))
		rows := make([]table.Row, 0, len(r.Components))
		for _, component := range r.Components {
			detail := component.Path
			if component.Kind == "binary" {
				if component.PathHit == "" {
					detail += " (not on PATH)"
				} else {
					detail += " (PATH: " + component.PathHit + ")"
				}
			}
			rows = append(rows, table.Row{statusBadge(component.Status), component.Kind, detail})
		}
		b.WriteString(statusTable(rows))
	}

	if len(r.Applications) > 0 {
		fmt.Fprintln(&b, accentStyle.Render("Kit applications"))
		rows := make([]table.Row, 0, len(r.Applications))
		for _, application := range r.Applications {
			rows = append(rows, table.Row{statusBadge(application.Status), application.Name, application.Destination})
		}
		b.WriteString(statusTable(rows))
	}

	if len(r.Fonts) > 0 {
		fmt.Fprintln(&b, accentStyle.Render("Nerd Fonts"))
		rows := make([]table.Row, 0, len(r.Fonts))
		for _, font := range r.Fonts {
			rows = append(rows, table.Row{statusBadge(font.Status), "JetBrainsMono", font.Path})
		}
		b.WriteString(statusTable(rows))
	}
	return b.String()
}

func statusSummary(name, value string) string {
	return lipgloss.NewStyle().Foreground(lipgloss.Color("245")).Width(12).Render(name) + value
}

func statusBadge(status string) string {
	switch status {
	case "installed":
		return okStyle.Render("INSTALLED")
	case "untracked":
		return warnStyle.Render("UNTRACKED")
	case "missing", "not installed", "managed block missing":
		return failStyle.Render(strings.ToUpper(status))
	default:
		return warnStyle.Render(strings.ToUpper(status))
	}
}

func statusTable(rows []table.Row) string {
	styles := table.DefaultStyles()
	styles.Header = styles.Header.Foreground(lipgloss.Color("51")).Bold(true)
	styles.Cell = styles.Cell.Foreground(lipgloss.Color("252"))
	model := table.New(
		table.WithColumns([]table.Column{
			{Title: "STATUS", Width: 18},
			{Title: "COMPONENT", Width: 22},
			{Title: "LOCATION", Width: 76},
		}),
		table.WithRows(rows),
		table.WithWidth(122),
		// The table header occupies three rendered lines, so leave room for
		// every row as well as the heading.
		table.WithHeight(len(rows)+4),
		table.WithFocused(false),
		table.WithStyles(styles),
	)
	return model.View() + "\n"
}
