package cli

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/spf13/cobra"
)

func wezCmd() *cobra.Command {
	c := &cobra.Command{Use: "wez", Short: "Try WezTerm presets in a new window"}
	c.AddCommand(&cobra.Command{Use: "list", Short: "List WezTerm presets", Args: cobra.NoArgs, RunE: func(cmd *cobra.Command, _ []string) error {
		_, err := fmt.Fprintln(cmd.OutOrStdout(), "current  Your existing WezTerm configuration\nkit      Bundled configuration with mouse paste\nplain    WezTerm defaults, without configuration\nx11      Bundled configuration using X11 instead of Wayland")
		return err
	}})
	var dryRun bool
	start := &cobra.Command{Use: "start [current|kit|plain|x11]", Short: "Open a preset without changing your configuration", Args: cobra.MaximumNArgs(1), RunE: func(cmd *cobra.Command, args []string) error {
		preset := "current"
		if len(args) == 1 {
			preset = args[0]
		}
		wezArgs, err := wezPresetArgs(preset)
		if err != nil {
			return err
		}
		if dryRun {
			fmt.Fprint(cmd.OutOrStdout(), "wezterm")
			for _, arg := range wezArgs {
				fmt.Fprint(cmd.OutOrStdout(), " '"+strings.ReplaceAll(arg, "'", "'\"'\"'")+"'")
			}
			_, err = fmt.Fprintln(cmd.OutOrStdout())
			return err
		}
		process := exec.CommandContext(cmd.Context(), "wezterm", wezArgs...)
		process.Stdin, process.Stdout, process.Stderr = cmd.InOrStdin(), cmd.OutOrStdout(), cmd.ErrOrStderr()
		if err := process.Run(); err != nil {
			return fmt.Errorf("start WezTerm preset %s: %w", preset, err)
		}
		return nil
	}}
	start.Flags().BoolVar(&dryRun, "dry-run", false, "Print the launch command without opening a window")
	c.AddCommand(start)
	return c
}

func wezPresetArgs(preset string) ([]string, error) {
	var args []string
	switch preset {
	case "current":
	case "plain":
		args = append(args, "--skip-config")
	case "kit", "x11":
		root, err := kitRoot()
		if err != nil {
			return nil, err
		}
		config := filepath.Join(root, "config", "wezterm", ".config", "wezterm", "wezterm.lua")
		if _, err := os.Stat(config); err != nil {
			return nil, fmt.Errorf("find bundled WezTerm configuration: %w", err)
		}
		args = append(args, "--config-file", config)
		if preset == "x11" {
			args = append(args, "--config", "enable_wayland=false")
		}
	default:
		return nil, fmt.Errorf("unknown WezTerm preset %q; run 'airgap wez list'", preset)
	}
	return append(args, "start", "--always-new-process"), nil
}
