package cli

import (
	"fmt"
	"io"
	"os"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/spf13/cobra"
	"golang.org/x/term"
)

var (
	accentStyle = lipgloss.NewStyle().Foreground(lipgloss.Color("99")).Bold(true)
	titleStyle  = lipgloss.NewStyle().Foreground(lipgloss.Color("212")).Bold(true)
	okStyle     = lipgloss.NewStyle().Foreground(lipgloss.Color("42"))
	warnStyle   = lipgloss.NewStyle().Foreground(lipgloss.Color("214"))
	failStyle   = lipgloss.NewStyle().Foreground(lipgloss.Color("196")).Bold(true)
	pathStyle   = lipgloss.NewStyle().Foreground(lipgloss.Color("51"))
	fileStyle   = lipgloss.NewStyle().Foreground(lipgloss.Color("111"))
	dimStyle    = lipgloss.NewStyle().Foreground(lipgloss.Color("245"))
)

func colorEnabled(cmd *cobra.Command) bool {
	if os.Getenv("NO_COLOR") != "" || os.Getenv("TERM") == "dumb" {
		return false
	}
	file, ok := cmd.OutOrStdout().(*os.File)
	return ok && term.IsTerminal(int(file.Fd()))
}

func styled(cmd *cobra.Command, style lipgloss.Style, value string) string {
	if !colorEnabled(cmd) {
		return value
	}
	return style.Render(value)
}

func writeHelp(cmd *cobra.Command) error {
	out := cmd.OutOrStdout()
	name := cmd.CommandPath()
	if _, err := fmt.Fprintln(out, styled(cmd, titleStyle, "Air-Gap Development Kit")); err != nil {
		return err
	}
	if _, err := fmt.Fprintln(out, styled(cmd, dimStyle, "Offline-first Linux development tooling")); err != nil {
		return err
	}
	if _, err := fmt.Fprintf(out, "\n%s\n  %s\n", styled(cmd, accentStyle, "Usage"), name+" [command] [flags]"); err != nil {
		return err
	}
	if cmd.Name() == "install" {
		if _, err := fmt.Fprintln(out, styled(cmd, accentStyle, "Installer options")); err != nil {
			return err
		}
		_, err := fmt.Fprintln(out, "  --no-tui              Use deterministic text instead of the install UI\n  --dry-run, -n          Preview without changing files\n  --nvim-mode MODE       preserve or replace the Neovim profile\n  --cli-only             Skip GUI payloads")
		return err
	}
	if _, err := fmt.Fprintln(out, styled(cmd, accentStyle, "Commands")); err != nil {
		return err
	}
	for _, child := range cmd.Commands() {
		if child.IsAvailableCommand() && !child.Hidden {
			if _, err := fmt.Fprintf(out, "  %-14s %s\n", child.Name(), child.Short); err != nil {
				return err
			}
		}
	}
	if _, err := fmt.Fprintf(out, "\n%s\n  %s\n", styled(cmd, accentStyle, "Global flags"), "--output text|json"); err != nil {
		return err
	}
	_, err := fmt.Fprintln(out, styled(cmd, dimStyle, "Run 'airgap <command> --help' for command details."))
	return err
}

type installModel struct {
	accepted bool
	canceled bool
}

func (m installModel) Init() tea.Cmd { return nil }

func (m installModel) Update(message tea.Msg) (tea.Model, tea.Cmd) {
	if key, ok := message.(tea.KeyMsg); ok {
		switch key.String() {
		case "enter", "y":
			m.accepted = true
			return m, tea.Quit
		case "q", "n", "esc", "ctrl+c":
			m.canceled = true
			return m, tea.Quit
		}
	}
	return m, nil
}

func (m installModel) View() string {
	return "\n" + titleStyle.Render("Airgap offline install") + "\n\n" +
		"This uses only the extracted kit payload. No network access is required.\n\n" +
		okStyle.Render("Enter") + " install    " + warnStyle.Render("q") + " cancel\n"
}

func wantsTUI(args []string) bool {
	if os.Getenv("NO_COLOR") != "" || os.Getenv("TERM") == "dumb" || !term.IsTerminal(int(os.Stdin.Fd())) || !term.IsTerminal(int(os.Stdout.Fd())) {
		return false
	}
	for _, arg := range args {
		if arg == "--yes" || arg == "--no-tui" || arg == "--dry-run" || arg == "-n" {
			return false
		}
	}
	return true
}

func withoutTUIFlag(args []string) []string {
	filtered := make([]string, 0, len(args))
	for _, arg := range args {
		if arg != "--no-tui" {
			filtered = append(filtered, arg)
		}
	}
	return filtered
}

func confirmInstall(cmd *cobra.Command) (bool, error) {
	program := tea.NewProgram(installModel{}, tea.WithInput(cmd.InOrStdin()), tea.WithOutput(cmd.OutOrStdout()))
	model, err := program.Run()
	if err != nil {
		return false, fmt.Errorf("run install interface: %w", err)
	}
	result, ok := model.(installModel)
	if !ok {
		return false, fmt.Errorf("unexpected install interface result")
	}
	return result.accepted && !result.canceled, nil
}

func renderText(cmd *cobra.Command, value string) string {
	if !colorEnabled(cmd) {
		return value
	}
	lines := strings.Split(strings.TrimSuffix(value, "\n"), "\n")
	for index, line := range lines {
		if before, after, found := strings.Cut(line, ":"); found {
			lines[index] = accentStyle.Render(before+":") + " " + after
		}
	}
	return strings.Join(lines, "\n") + "\n"
}

func writeStyledText(cmd *cobra.Command, output io.Writer, value string) error {
	_, err := fmt.Fprint(output, renderText(cmd, value))
	return err
}
