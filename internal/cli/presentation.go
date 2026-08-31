package cli

import (
	"fmt"
	"io"
	"os"
	"strings"

	tea "charm.land/bubbletea/v2"
	"charm.land/lipgloss/v2"
	"github.com/spf13/cobra"
	"github.com/spf13/pflag"
	"golang.org/x/term"
)

var (
	accentStyle = lipgloss.NewStyle().Foreground(lipgloss.Color("39")).Bold(true)
	titleStyle  = lipgloss.NewStyle().Foreground(lipgloss.Color("51")).Bold(true)
	okStyle     = lipgloss.NewStyle().Foreground(lipgloss.Color("42"))
	warnStyle   = lipgloss.NewStyle().Foreground(lipgloss.Color("214"))
	failStyle   = lipgloss.NewStyle().Foreground(lipgloss.Color("196")).Bold(true)
	pathStyle   = lipgloss.NewStyle().Foreground(lipgloss.Color("51"))
	fileStyle   = lipgloss.NewStyle().Foreground(lipgloss.Color("111"))
	dimStyle    = lipgloss.NewStyle().Foreground(lipgloss.Color("245"))

	installerFrameStyle = lipgloss.NewStyle().
				Border(lipgloss.RoundedBorder()).
				BorderForeground(lipgloss.Color("63")).
				Padding(1, 2)
	installerTitleStyle = lipgloss.NewStyle().
				Foreground(lipgloss.Color("213")).
				Bold(true)
	installerActiveStepStyle = lipgloss.NewStyle().
					Foreground(lipgloss.Color("51")).
					Bold(true)
	installerStepStyle     = lipgloss.NewStyle().Foreground(lipgloss.Color("241"))
	installerSelectedStyle = lipgloss.NewStyle().
				Foreground(lipgloss.Color("231")).
				Background(lipgloss.Color("57")).
				Bold(true).
				Padding(0, 1)
	installerOptionStyle = lipgloss.NewStyle().
				Foreground(lipgloss.Color("252")).
				Padding(0, 1)
	installerSafetyStyle = lipgloss.NewStyle().
				Foreground(lipgloss.Color("214")).
				Border(lipgloss.RoundedBorder()).
				BorderForeground(lipgloss.Color("214")).
				Padding(0, 1)
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
	if cmd.HasAvailableSubCommands() {
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
	} else if cmd.NonInheritedFlags().HasAvailableFlags() {
		if _, err := fmt.Fprintln(out, styled(cmd, accentStyle, "Options")); err != nil {
			return err
		}
		cmd.NonInheritedFlags().VisitAll(func(flag *pflag.Flag) {
			if flag.Hidden {
				return
			}
			name := "--" + flag.Name
			if flag.Shorthand != "" {
				name = "-" + flag.Shorthand + ", " + name
			}
			if flag.Value.Type() != "bool" {
				name += " " + strings.ToUpper(flag.Value.Type())
			}
			fmt.Fprintf(out, "  %-27s %s\n", name, flag.Usage)
		})
	}
	if _, err := fmt.Fprintf(out, "\n%s\n  %s\n", styled(cmd, accentStyle, "Global flags"), "--output text|json"); err != nil {
		return err
	}
	_, err := fmt.Fprintln(out, styled(cmd, dimStyle, "Run 'airgap <command> --help' for command details."))
	return err
}

type installModel struct {
	options      installOptions
	existingNvim bool
	step         int
	choice       int
	accepted     bool
	canceled     bool
}

func (m installModel) Init() tea.Cmd { return nil }

func (m installModel) Update(message tea.Msg) (tea.Model, tea.Cmd) {
	if key, ok := message.(tea.KeyPressMsg); ok {
		switch key.String() {
		case "up", "k":
			if m.choice > 0 {
				m.choice--
			}
		case "down", "j":
			if m.choice < len(m.choices())-1 {
				m.choice++
			}
		case "enter":
			if m.step == 3 {
				m.accepted = true
				return m, tea.Quit
			}
			m.applyChoice()
			m.step++
			m.choice = m.selectedChoice()
		case "b", "left":
			if m.step > 0 {
				m.step--
				m.choice = m.selectedChoice()
			}
		case "q", "n", "esc", "ctrl+c":
			m.canceled = true
			return m, tea.Quit
		}
	}
	return m, nil
}

func (m installModel) View() tea.View {
	var b strings.Builder
	b.WriteString(installerTitleStyle.Render("✦ Airgap Setup") + "  " + dimStyle.Render("offline kit installer") + "\n")
	b.WriteString(m.stepper() + "\n\n")
	if m.step == 3 {
		b.WriteString(accentStyle.Render("Ready to apply this plan") + "\n\n")
		profile := "Full kit"
		if m.options.CLIOnly {
			profile = "CLI-only kit · GUI payloads skipped"
		}
		b.WriteString(okStyle.Render("●") + " Package  " + profile + "\n")
		nvim := "Install bundled Neovim and LazyVim"
		if m.existingNvim && m.options.NvimMode == "preserve" {
			nvim = "Preserve the existing Neovim profile"
		} else if m.existingNvim && m.options.NvimMode == "replace" {
			nvim = "Back up and replace the Neovim profile"
		} else if m.existingNvim {
			nvim = "Delete and overwrite the Neovim profile"
		}
		b.WriteString(okStyle.Render("●") + " Neovim   " + nvim + "\n")
		shell := "Do not change shell startup files"
		if m.options.ConfigureShell {
			shell = "Add the managed Bash/Zsh integration"
		}
		b.WriteString(okStyle.Render("●") + " Shell     " + shell + "\n")
		if m.existingNvim && m.options.NvimMode == "replace" {
			b.WriteString("\n" + installerSafetyStyle.Render("Backup first: your complete Neovim profile will be moved to ~/.local/share/airgap-dev-kit/backups/.") + "\n")
		} else if m.existingNvim && m.options.NvimMode == "overwrite" {
			b.WriteString("\n" + installerSafetyStyle.Render("Permanent deletion: the existing Neovim profile, state, and cache will be removed without a backup.") + "\n")
		}
		b.WriteString("\n" + dimStyle.Render("Nothing has changed yet.") + "\n\n")
		b.WriteString(okStyle.Render("Enter") + " install    " + warnStyle.Render("b") + " back    " + warnStyle.Render("q") + " cancel")
		return tea.NewView("\n" + installerFrameStyle.Render(b.String()) + "\n")
	}
	b.WriteString(accentStyle.Render(m.question()) + "\n")
	if m.step == 1 && m.existingNvim {
		b.WriteString(installerSafetyStyle.Render("Existing Neovim, LazyVim, Mason, state, and cache were found. Choose preserve, back up and replace, or permanent deletion and overwrite.") + "\n\n")
	}
	if m.step == 2 {
		b.WriteString(dimStyle.Render("This adds one removable Airgap block to Bash/Zsh. It enables PATH, FZF keys/completion, zoxide, and Starship.") + "\n\n")
	}
	for index, choice := range m.choices() {
		marker := "  "
		style := installerOptionStyle
		if index == m.choice {
			marker = "› "
			style = installerSelectedStyle
		}
		b.WriteString(style.Render(marker+choice) + "\n")
	}
	b.WriteString("\n" + dimStyle.Render("↑/k and ↓/j choose  ·  Enter continue  ·  b back  ·  q cancel"))
	return tea.NewView("\n" + installerFrameStyle.Render(b.String()) + "\n")
}

func (m installModel) stepper() string {
	steps := []string{"Package", "Neovim", "Shell", "Review"}
	parts := make([]string, 0, len(steps))
	for index, step := range steps {
		style := installerStepStyle
		icon := "○"
		if index < m.step {
			style = okStyle
			icon = "✓"
		} else if index == m.step {
			style = installerActiveStepStyle
			icon = "●"
		}
		parts = append(parts, style.Render(icon+" "+step))
	}
	return strings.Join(parts, installerStepStyle.Render("  ─  "))
}

func (m installModel) question() string {
	switch m.step {
	case 0:
		return "Choose package profile"
	case 1:
		return "Choose Neovim configuration handling"
	default:
		return "Configure shell integration?"
	}
}

func (m installModel) choices() []string {
	switch m.step {
	case 0:
		return []string{"Full kit — include all available payloads", "CLI-only kit — skip GUI payloads"}
	case 1:
		if m.existingNvim {
			return []string{"Preserve existing profile — do not change Neovim or LazyVim", "Back up and replace — save the complete profile, then install a fresh kit", "Delete and overwrite — permanently remove the profile, then install a fresh kit"}
		}
		return []string{"Install the bundled Neovim and LazyVim profile"}
	default:
		return []string{"Yes — add the managed Bash/Zsh integration", "No — leave shell startup files unchanged"}
	}
}

func (m *installModel) applyChoice() {
	switch m.step {
	case 0:
		m.options.CLIOnly = m.choice == 1
	case 1:
		if m.existingNvim {
			m.options.NvimMode = "preserve"
			if m.choice == 1 {
				m.options.NvimMode = "replace"
			} else if m.choice == 2 {
				m.options.NvimMode = "overwrite"
			}
		}
	case 2:
		m.options.ConfigureShell = m.choice == 0
	}
}

func (m installModel) selectedChoice() int {
	switch m.step {
	case 0:
		if m.options.CLIOnly {
			return 1
		}
	case 1:
		if m.existingNvim && m.options.NvimMode == "replace" {
			return 1
		} else if m.existingNvim && m.options.NvimMode == "overwrite" {
			return 2
		}
	case 2:
		if !m.options.ConfigureShell {
			return 1
		}
	}
	return 0
}

func wantsTUI(args []string) bool {
	if os.Getenv("NO_COLOR") != "" || os.Getenv("TERM") == "dumb" || !term.IsTerminal(int(os.Stdin.Fd())) || !term.IsTerminal(int(os.Stdout.Fd())) {
		return false
	}
	for _, arg := range args {
		if arg == "--yes" || arg == "--dry-run" || arg == "-n" {
			return false
		}
	}
	return true
}

func planInstall(cmd *cobra.Command, options installOptions, existingNvim bool, _ []toolChoice) (installOptions, bool, error) {
	model := installModel{options: options, existingNvim: existingNvim}
	model.choice = model.selectedChoice()
	program := tea.NewProgram(model, tea.WithInput(cmd.InOrStdin()), tea.WithOutput(cmd.OutOrStdout()))
	resultModel, err := program.Run()
	if err != nil {
		return options, false, fmt.Errorf("run install interface: %w", err)
	}
	result, ok := resultModel.(installModel)
	if !ok {
		return options, false, fmt.Errorf("unexpected install interface result")
	}
	return result.options, result.accepted && !result.canceled, nil
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
