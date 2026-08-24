package cli

import (
	"fmt"
	"strings"

	"charm.land/bubbles/v2/progress"
	"charm.land/bubbles/v2/spinner"
	"charm.land/bubbles/v2/table"
	tea "charm.land/bubbletea/v2"
	"charm.land/lipgloss/v2"
	"github.com/spf13/cobra"
)

// installStep is one recoverable part of a native kit installation.
type installStep struct {
	label   string
	result  string
	details string
	action  func() error
}

type installStepDone struct{ err error }

type installProgressModel struct {
	steps   []installStep
	current int
	results []table.Row
	spinner spinner.Model
	bar     progress.Model
	done    bool
	err     error
}

func newInstallProgressModel(steps []installStep) installProgressModel {
	return installProgressModel{
		steps:   steps,
		spinner: spinner.New(spinner.WithSpinner(spinner.Dot), spinner.WithStyle(accentStyle)),
		bar: progress.New(
			progress.WithWidth(44),
			progress.WithColors(lipgloss.Color("51"), lipgloss.Color("213")),
		),
	}
}

func (m installProgressModel) Init() tea.Cmd {
	if len(m.steps) == 0 {
		return nil
	}
	return tea.Batch(m.spinner.Tick, m.runCurrent())
}

func (m installProgressModel) runCurrent() tea.Cmd {
	step := m.steps[m.current]
	return func() tea.Msg { return installStepDone{err: step.action()} }
}

func (m installProgressModel) Update(message tea.Msg) (tea.Model, tea.Cmd) {
	if !m.done {
		var spinnerCmd, progressCmd tea.Cmd
		m.spinner, spinnerCmd = m.spinner.Update(message)
		m.bar, progressCmd = m.bar.Update(message)
		switch message := message.(type) {
		case installStepDone:
			step := m.steps[m.current]
			if message.err != nil {
				m.err = message.err
				m.done = true
				return m, nil
			}
			m.results = append(m.results, table.Row{step.result, step.label, step.details})
			m.current++
			barCmd := m.bar.SetPercent(float64(m.current) / float64(len(m.steps)))
			if m.current == len(m.steps) {
				m.done = true
				return m, barCmd
			}
			return m, tea.Batch(spinnerCmd, progressCmd, barCmd, m.runCurrent())
		}
		return m, tea.Batch(spinnerCmd, progressCmd)
	}

	if key, ok := message.(tea.KeyPressMsg); ok {
		switch key.String() {
		case "enter", "q", "esc", "ctrl+c":
			return m, tea.Quit
		}
	}
	return m, nil
}

func (m installProgressModel) View() tea.View {
	var content strings.Builder
	content.WriteString(installerTitleStyle.Render("✦ Airgap Setup") + "  " + dimStyle.Render("offline installation") + "\n\n")
	if m.err != nil {
		failed := m.steps[m.current].label
		content.WriteString(failStyle.Render("Installation stopped") + "\n\n")
		content.WriteString(installerSafetyStyle.Render("Failed step: "+failed) + "\n\n")
		content.WriteString("  " + m.err.Error() + "\n\n")
		content.WriteString(dimStyle.Render("Recovery: run airgap doctor, correct the issue, then rerun airgap install.") + "\n\n")
		content.WriteString(dimStyle.Render("Enter, q, or Esc closes this report."))
		return tea.NewView("\n" + installerFrameStyle.Render(content.String()) + "\n")
	}

	if m.done {
		content.WriteString(okStyle.Render("✓ Installation complete") + "\n")
		content.WriteString(dimStyle.Render("Everything below is user-local and tracked for safe uninstall.") + "\n\n")
		content.WriteString(m.resultTable().View() + "\n\n")
		content.WriteString(accentStyle.Render("Next") + "  Restart your shell, then run airgap status.\n\n")
		content.WriteString(dimStyle.Render("Enter, q, or Esc closes this summary."))
		return tea.NewView("\n" + installerFrameStyle.Render(content.String()) + "\n")
	}

	content.WriteString(accentStyle.Render("Installing your offline kit") + "\n")
	content.WriteString(m.bar.ViewAs(float64(m.current)/float64(len(m.steps))) + "\n\n")
	for index, step := range m.steps {
		switch {
		case index < m.current:
			content.WriteString(okStyle.Render("✓ "+step.label) + "\n")
		case index == m.current:
			content.WriteString(m.spinner.View() + " " + installerActiveStepStyle.Render(step.label) + "\n")
		default:
			content.WriteString(installerStepStyle.Render("○ "+step.label) + "\n")
		}
	}
	content.WriteString("\n" + dimStyle.Render("Please keep this terminal open while files are copied."))
	return tea.NewView("\n" + installerFrameStyle.Render(content.String()) + "\n")
}

func (m installProgressModel) resultTable() table.Model {
	styles := table.DefaultStyles()
	styles.Header = styles.Header.Foreground(lipgloss.Color("51"))
	styles.Cell = styles.Cell.Foreground(lipgloss.Color("252"))
	return table.New(
		table.WithColumns([]table.Column{{Title: "Result", Width: 11}, {Title: "Action", Width: 31}, {Title: "Details", Width: 36}}),
		table.WithRows(m.results),
		table.WithHeight(len(m.results)+2),
		table.WithWidth(82),
		table.WithStyles(styles),
	)
}

func runInstallProgress(cmd *cobra.Command, steps []installStep) error {
	program := tea.NewProgram(newInstallProgressModel(steps), tea.WithInput(cmd.InOrStdin()), tea.WithOutput(cmd.OutOrStdout()))
	model, err := program.Run()
	if err != nil {
		return fmt.Errorf("run installation progress interface: %w", err)
	}
	result, ok := model.(installProgressModel)
	if !ok {
		return fmt.Errorf("unexpected installation progress result")
	}
	if result.err != nil {
		return fmt.Errorf("install %s: %w", result.steps[result.current].label, result.err)
	}
	return nil
}

func runInstallText(cmd *cobra.Command, steps []installStep) error {
	for index, step := range steps {
		if _, err := fmt.Fprintf(cmd.OutOrStdout(), "[%d/%d] %s...\n", index+1, len(steps), step.label); err != nil {
			return err
		}
		if err := step.action(); err != nil {
			return fmt.Errorf("install %s: %w", step.label, err)
		}
		if _, err := fmt.Fprintf(cmd.OutOrStdout(), "  ✓ %s\n", step.result); err != nil {
			return err
		}
	}
	return nil
}
