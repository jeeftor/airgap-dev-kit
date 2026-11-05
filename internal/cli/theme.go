package cli

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"strings"

	"github.com/spf13/cobra"
)

func themeCmd() *cobra.Command {
	command := &cobra.Command{Use: "theme", Short: "Choose matching offline terminal colors"}
	list := func(cmd *cobra.Command, _ []string) error {
		fmt.Fprintln(cmd.OutOrStdout(), "default    Restore terminal configuration colors")
		for _, theme := range terminalThemes {
			fmt.Fprintf(cmd.OutOrStdout(), "%-10s %s\n", theme.Name, theme.Description)
		}
		fmt.Fprintln(cmd.OutOrStdout(), "\nSave: airgap theme set monokai\nTry:  airgap theme start kitty paper")
		return nil
	}
	command.RunE = list
	command.Args = cobra.NoArgs
	command.AddCommand(&cobra.Command{Use: "list", Short: "List bundled terminal themes", Args: cobra.NoArgs, RunE: list})
	var terminal string
	var dryRun bool
	set := &cobra.Command{Use: "set <theme>", Short: "Save a theme for your kit-managed terminals", Args: cobra.ExactArgs(1), RunE: func(cmd *cobra.Command, args []string) error {
		return setTerminalTheme(cmd, args[0], terminal, dryRun)
	}}
	set.Flags().StringVar(&terminal, "terminal", "all", "Apply to: all, kitty, ghostty, or wezterm")
	set.Flags().BoolVarP(&dryRun, "dry-run", "n", false, "Preview changes without writing files")
	command.AddCommand(set)
	command.AddCommand(&cobra.Command{Use: "start <terminal> <theme>", Short: "Try a theme in a new window without saving it", Args: cobra.ExactArgs(2), RunE: func(cmd *cobra.Command, args []string) error {
		return startTerminalTheme(cmd, args[0], args[1])
	}})
	return command
}

func startTerminalTheme(cmd *cobra.Command, terminal, name string) error {
	theme, err := findTerminalTheme(name)
	if err != nil {
		return err
	}
	config, err := terminalThemeConfig(terminal, theme)
	if err != nil {
		return err
	}
	var args []string
	switch terminal {
	case "kitty":
		for _, line := range strings.Split(config, "\n") {
			if line == "" || strings.HasPrefix(line, "#") {
				continue
			}
			key, value, _ := strings.Cut(line, " ")
			args = append(args, "--override", key+"="+value)
		}
	case "ghostty":
		// Load the preview after any saved theme includes. A separate process
		// keeps its configuration and the temporary file tied to this window.
		directory, err := os.MkdirTemp("", "airgap-theme-")
		if err != nil {
			return err
		}
		defer os.RemoveAll(directory)
		path := filepath.Join(directory, "theme.conf")
		if err := os.WriteFile(path, []byte(config), 0600); err != nil {
			return err
		}
		args = []string{"--gtk-single-instance=false", "--config-file=" + path}
	case "wezterm":
		args = []string{"--config", "colors=" + strings.SplitN(config, "return ", 2)[1], "start", "--always-new-process"}
	}
	process := exec.CommandContext(cmd.Context(), terminal, args...)
	process.Stdin, process.Stdout, process.Stderr = cmd.InOrStdin(), cmd.OutOrStdout(), cmd.ErrOrStderr()
	if err := process.Run(); err != nil {
		return fmt.Errorf("start %s with theme %s: %w", terminal, name, err)
	}
	return nil
}

type terminalThemeChange struct {
	terminal, configPath, themePath string
	config, colors                  []byte
	mode                            os.FileMode
	addInclude                      bool
}

func setTerminalTheme(cmd *cobra.Command, name, terminal string, dryRun bool) error {
	var theme terminalTheme
	var err error
	if name != "default" {
		theme, err = findTerminalTheme(name)
		if err != nil {
			return err
		}
	}
	if !slices.Contains([]string{"all", "kitty", "ghostty", "wezterm"}, terminal) {
		return fmt.Errorf("unknown terminal %q; use all, kitty, ghostty, or wezterm", terminal)
	}
	path, err := installRecordPath()
	if err != nil {
		return err
	}
	raw, err := os.ReadFile(path)
	if err != nil {
		return fmt.Errorf("read installation record; install the kit before choosing a terminal theme: %w", err)
	}
	var record installRecord
	if err := json.Unmarshal(raw, &record); err != nil {
		return err
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return err
	}
	var changes []terminalThemeChange
	for _, candidate := range []struct{ terminal, file string }{{"kitty", "kitty.conf"}, {"ghostty", "config"}, {"wezterm", "wezterm.lua"}} {
		if terminal != "all" && terminal != candidate.terminal {
			continue
		}
		configDir := filepath.Join(home, ".config", candidate.terminal)
		paths := []string{filepath.Join(configDir, candidate.file)}
		if candidate.terminal == "wezterm" {
			if preset, found := installedWezPresetPath(); found {
				paths = append(paths, preset)
			}
		}
		for _, configPath := range paths {
			if !slices.Contains(record.Paths, configPath) {
				continue
			}
			change, err := prepareTerminalTheme(candidate.terminal, configPath, configDir, name, theme, record)
			if err != nil {
				return err
			}
			changes = append(changes, change)
		}
	}
	if len(changes) == 0 {
		return fmt.Errorf("no kit-managed %s terminal configuration found; your personal configurations are unchanged", terminal)
	}
	for _, change := range changes {
		if dryRun {
			fmt.Fprintf(cmd.OutOrStdout(), "would apply %s to %s (%s)\n", name, change.terminal, change.configPath)
			continue
		}
		if change.addInclude {
			backup, err := os.CreateTemp(filepath.Dir(change.configPath), filepath.Base(change.configPath)+".airgap-theme-backup-*")
			if err != nil {
				return err
			}
			backupPath := backup.Name()
			if err := backup.Close(); err != nil {
				return err
			}
			if err := copyFile(change.configPath, backupPath, 0600); err != nil {
				return fmt.Errorf("back up terminal configuration: %w", err)
			}
			fmt.Fprintln(cmd.OutOrStdout(), "backed up "+backupPath)
		}
		if err := writeAtomic(change.themePath, change.colors, 0644); err != nil {
			return err
		}
		if !slices.Contains(record.Paths, change.themePath) {
			record.Paths = append(record.Paths, change.themePath)
			if err := saveInstallRecord(record); err != nil {
				return err
			}
		}
		if change.addInclude {
			if err := writeAtomic(change.configPath, change.config, change.mode); err != nil {
				return err
			}
		}
		fmt.Fprintf(cmd.OutOrStdout(), "applied %s to %s (%s)\n", name, change.terminal, change.configPath)
	}
	if !dryRun {
		fmt.Fprintln(cmd.OutOrStdout(), "Open a new terminal window to use the theme. Personal configurations were left unchanged; for the managed WezTerm preset, use 'airgap wez start kit'.")
	}
	return nil
}

func prepareTerminalTheme(terminal, configPath, configDir, name string, theme terminalTheme, record installRecord) (terminalThemeChange, error) {
	change := terminalThemeChange{terminal: terminal, configPath: configPath}
	info, err := os.Lstat(configPath)
	if err != nil {
		return change, err
	}
	if !info.Mode().IsRegular() {
		return change, fmt.Errorf("terminal configuration must be a regular file: %s", configPath)
	}
	change.mode = info.Mode().Perm()
	change.config, err = os.ReadFile(configPath)
	if err != nil {
		return change, err
	}
	extension := ".conf"
	if terminal == "wezterm" {
		extension = ".lua"
	}
	change.themePath = filepath.Join(configDir, "airgap-theme"+extension)
	if _, err := os.Lstat(change.themePath); err == nil {
		if !slices.Contains(record.Paths, change.themePath) {
			return change, fmt.Errorf("refusing to replace an untracked theme file: %s", change.themePath)
		}
	} else if !os.IsNotExist(err) {
		return change, err
	}
	colors := "# Airgap theme: default\n"
	if terminal == "wezterm" {
		colors = "-- Airgap theme: default\nreturn nil\n"
	}
	if name != "default" {
		colors, err = terminalThemeConfig(terminal, theme)
		if err != nil {
			return change, err
		}
	}
	change.colors = []byte(colors)
	// The launcher applies colors to its managed preset as a command-line
	// override, so a system-wide preset never points at one user's home.
	if terminal == "wezterm" {
		if preset, found := installedWezPresetPath(); found && configPath == preset {
			return change, nil
		}
	}
	include := "\n# Airgap terminal theme\ninclude airgap-theme.conf\n"
	if terminal == "ghostty" {
		include = "\n# Airgap terminal theme\nconfig-file = airgap-theme.conf\n"
	}
	if terminal == "wezterm" {
		include = fmt.Sprintf("-- Airgap terminal theme\nlocal airgap_colors = dofile(%q)\nif airgap_colors then config.colors = airgap_colors end\n\n", change.themePath)
	}
	if !strings.Contains(string(change.config), include) {
		if terminal == "wezterm" {
			config := strings.TrimRight(string(change.config), "\r\n \t")
			if !strings.HasSuffix(config, "\nreturn config") {
				return change, fmt.Errorf("cannot add a theme to the modified WezTerm preset %s; expected its final 'return config'", configPath)
			}
			change.config = []byte(strings.TrimSuffix(config, "return config") + include + "return config\n")
		} else {
			change.config = append(change.config, include...)
		}
		change.addInclude = true
	}
	return change, nil
}
