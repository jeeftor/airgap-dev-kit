package cli

import (
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	tea "charm.land/bubbletea/v2"
	"charm.land/lipgloss/v2"
	"github.com/spf13/cobra"
)

type promptPreset struct {
	Name        string
	Description string
	Path        string
}

var promptPresetDescriptions = map[string]string{
	"minimal":   "directory and Git status",
	"developer": "Git plus Go, Python, Node, Rust, and command time",
	"ops":       "remote host, cloud context, status, and time",
	"plain":     "ASCII-safe symbols for any terminal",
}

// promptCmd manages the Starship configurations shipped inside an extracted kit.
func promptCmd() *cobra.Command {
	c := &cobra.Command{Use: "prompt", Short: "Choose an offline Starship prompt", RunE: runPromptPicker}
	c.AddCommand(promptListCmd(), promptPreviewCmd(), promptSetCmd())
	return c
}

func promptListCmd() *cobra.Command {
	return &cobra.Command{Use: "list", Short: "List bundled Starship prompt presets", RunE: func(cmd *cobra.Command, _ []string) error {
		presets, err := bundledPromptPresets()
		if err != nil {
			return err
		}
		for _, preset := range presets {
			fmt.Fprintf(cmd.OutOrStdout(), "%-10s %s\n", preset.Name, preset.Description)
		}
		return nil
	}}
}

func promptPreviewCmd() *cobra.Command {
	return &cobra.Command{Use: "preview <preset>", Short: "Print a bundled Starship prompt preset", Args: cobra.ExactArgs(1), RunE: func(cmd *cobra.Command, args []string) error {
		preset, err := findPromptPreset(args[0])
		if err != nil {
			return err
		}
		content, err := os.ReadFile(preset.Path)
		if err != nil {
			return fmt.Errorf("read %s: %w", preset.Name, err)
		}
		_, err = fmt.Fprint(cmd.OutOrStdout(), string(content))
		return err
	}}
}

func promptSetCmd() *cobra.Command {
	var dryRun, yes bool
	c := &cobra.Command{Use: "set <preset>", Short: "Activate a bundled Starship prompt preset", Args: cobra.ExactArgs(1), RunE: func(cmd *cobra.Command, args []string) error {
		return setPromptPreset(cmd.OutOrStdout(), args[0], dryRun, yes)
	}}
	c.Flags().BoolVarP(&dryRun, "dry-run", "n", false, "Show the config change without writing files")
	c.Flags().BoolVarP(&yes, "yes", "y", false, "Confirm changing the Starship config")
	return c
}

func bundledPromptPresets() ([]promptPreset, error) {
	root, err := kitRoot()
	if err != nil {
		return nil, err
	}
	dir := filepath.Join(root, "config", "starship-presets")
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil, fmt.Errorf("read bundled Starship presets: %w", err)
	}
	var presets []promptPreset
	for _, entry := range entries {
		if entry.IsDir() || filepath.Ext(entry.Name()) != ".toml" {
			continue
		}
		name := strings.TrimSuffix(entry.Name(), ".toml")
		description, ok := promptPresetDescriptions[name]
		if !ok {
			description = "bundled Starship configuration"
		}
		presets = append(presets, promptPreset{Name: name, Description: description, Path: filepath.Join(dir, entry.Name())})
	}
	sort.Slice(presets, func(i, j int) bool { return presets[i].Name < presets[j].Name })
	if len(presets) == 0 {
		return nil, fmt.Errorf("no bundled Starship presets found in %s", dir)
	}
	return presets, nil
}

func findPromptPreset(name string) (promptPreset, error) {
	presets, err := bundledPromptPresets()
	if err != nil {
		return promptPreset{}, err
	}
	for _, preset := range presets {
		if preset.Name == name {
			return preset, nil
		}
	}
	return promptPreset{}, fmt.Errorf("unknown prompt preset %q; run 'airgap prompt list'", name)
}

func setPromptPreset(output io.Writer, name string, dryRun, yes bool) error {
	preset, err := findPromptPreset(name)
	if err != nil {
		return err
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return err
	}
	destination := filepath.Join(home, ".config", "starship.toml")
	if dryRun {
		fmt.Fprintf(output, "would activate %q at %s\n", preset.Name, destination)
		if _, err := os.Stat(destination); err == nil {
			fmt.Fprintln(output, "would back up the existing Starship config first")
		}
		return nil
	}
	if !yes {
		return fmt.Errorf("prompt set requires --yes unless --dry-run is used")
	}
	if _, err := os.Stat(destination); err == nil {
		backup := destination + ".airgap-backup-" + time.Now().UTC().Format("20060102-150405")
		if err := copyFile(destination, backup, 0600); err != nil {
			return fmt.Errorf("back up existing Starship config: %w", err)
		}
		fmt.Fprintln(output, "backed up "+destination+" to "+backup)
	} else if !os.IsNotExist(err) {
		return fmt.Errorf("inspect existing Starship config: %w", err)
	}
	if err := copyFile(preset.Path, destination, 0644); err != nil {
		return fmt.Errorf("activate %s prompt: %w", preset.Name, err)
	}
	fmt.Fprintf(output, "activated %q Starship prompt at %s\n", preset.Name, destination)
	return nil
}

type promptPickerModel struct {
	presets []promptPreset
	cursor  int
	chosen  string
	cancel  bool
}

func (m promptPickerModel) Init() tea.Cmd { return nil }

func (m promptPickerModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	if key, ok := msg.(tea.KeyPressMsg); ok {
		switch key.String() {
		case "q", "esc", "ctrl+c":
			m.cancel = true
			return m, tea.Quit
		case "up", "k":
			if m.cursor > 0 {
				m.cursor--
			}
		case "down", "j":
			if m.cursor < len(m.presets)-1 {
				m.cursor++
			}
		case "enter":
			m.chosen = m.presets[m.cursor].Name
			return m, tea.Quit
		}
	}
	return m, nil
}

func (m promptPickerModel) View() tea.View {
	var body strings.Builder
	body.WriteString("Choose a Starship prompt\n\n")
	for i, preset := range m.presets {
		marker := "  "
		if i == m.cursor {
			marker = "› "
		}
		body.WriteString(marker + preset.Name + " — " + preset.Description + "\n")
	}
	body.WriteString("\n↑/k and ↓/j choose  ·  Enter activate  ·  q cancel")
	return tea.NewView(lipgloss.NewStyle().Border(lipgloss.RoundedBorder()).BorderForeground(lipgloss.Color("63")).Padding(1, 2).Render(body.String()))
}

func runPromptPicker(cmd *cobra.Command, _ []string) error {
	if !wantsTUI(nil) {
		return fmt.Errorf("prompt selection requires an interactive terminal; use 'airgap prompt list' or 'airgap prompt set <preset> --yes'")
	}
	presets, err := bundledPromptPresets()
	if err != nil {
		return err
	}
	program := tea.NewProgram(promptPickerModel{presets: presets}, tea.WithOutput(cmd.OutOrStdout()))
	model, err := program.Run()
	if err != nil {
		return err
	}
	picker, ok := model.(promptPickerModel)
	if !ok || picker.cancel || picker.chosen == "" {
		fmt.Fprintln(cmd.OutOrStdout(), "Prompt selection cancelled.")
		return nil
	}
	return setPromptPreset(cmd.OutOrStdout(), picker.chosen, false, true)
}
