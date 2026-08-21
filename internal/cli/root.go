// Package cli defines the supported airgap command line contract.
package cli

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"

	"github.com/spf13/cobra"
	"github.com/spf13/viper"
)

// New builds the command tree. Filesystem mutations remain in the established
// lifecycle scripts until their transaction semantics have direct Go coverage.
func New(version, commit string) *cobra.Command {
	var output string
	root := &cobra.Command{
		Use:           "airgap",
		Short:         "Manage an offline Air-Gap Development Kit",
		SilenceUsage:  true,
		SilenceErrors: true,
	}
	root.PersistentFlags().StringVar(&output, "output", "text", "Output format: text or json")
	_ = viper.BindPFlag("output", root.PersistentFlags().Lookup("output"))
	root.SetHelpFunc(func(command *cobra.Command, _ []string) { _ = writeHelp(command) })
	root.AddCommand(versionCmd(version, commit), statusCmd(&output), doctorCmd(&output, version, commit))
	root.AddCommand(legacyCmd("install", "Install a kit from an offline payload", "install.sh"))
	root.AddCommand(legacyCmd("uninstall", "Uninstall only tracked kit paths", "uninstall.sh"))
	root.AddCommand(cleanCmd())
	root.AddCommand(updateCmd(version))
	root.AddCommand(completionCmd(root))
	root.AddCommand(aliasCmd())
	return root
}

func versionCmd(version, commit string) *cobra.Command {
	return &cobra.Command{Use: "version", Short: "Print the airgap version", RunE: func(cmd *cobra.Command, _ []string) error {
		return jsonOrText(cmd, map[string]string{"version": version, "commit": commit}, fmt.Sprintf("airgap %s (%s)\n", version, commit))
	}}
}

func statusCmd(output *string) *cobra.Command {
	return &cobra.Command{Use: "status", Short: "Show kit location and supported target", RunE: func(cmd *cobra.Command, _ []string) error {
		root, found := discoveredKitRoot()
		kitDir := "not found"
		if found {
			kitDir = root
		}
		executable, err := os.Executable()
		if err != nil {
			return err
		}
		return jsonOrText(cmd, map[string]any{"kit_dir": root, "kit_available": found, "executable": executable, "target": runtime.GOOS + "/" + runtime.GOARCH}, fmt.Sprintf("Executable: %s\nKit directory: %s\nKit available: %t\nTarget: %s/%s\n", executable, kitDir, found, runtime.GOOS, runtime.GOARCH))
	}}
}

func legacyCmd(name, short, script string) *cobra.Command {
	use := name
	if name == "install" {
		use = "install [installer options]"
	}
	return &cobra.Command{Use: use, Short: short, DisableFlagParsing: true, RunE: func(cmd *cobra.Command, args []string) error {
		if name == "install" {
			for _, arg := range args {
				if arg == "--help" || arg == "-h" {
					return writeHelp(cmd)
				}
			}
		}
		if name == "install" && wantsTUI(args) {
			confirmed, err := confirmInstall(cmd)
			if err != nil {
				return err
			}
			if !confirmed {
				_, err := fmt.Fprintln(cmd.OutOrStdout(), "Install cancelled.")
				return err
			}
		}
		root, err := kitRoot()
		if err != nil {
			return err
		}
		path := filepath.Join(root, script)
		if _, err := os.Stat(path); err != nil {
			return fmt.Errorf("%s is unavailable: %w", script, err)
		}
		child := exec.Command(path, withoutTUIFlag(args)...)
		child.Dir, child.Stdin, child.Stdout, child.Stderr = root, cmd.InOrStdin(), cmd.OutOrStdout(), cmd.ErrOrStderr()
		return child.Run()
	}}
}

func cleanCmd() *cobra.Command {
	var dryRun, yes bool
	c := &cobra.Command{Use: "clean", Short: "Remove interrupted update downloads", RunE: func(cmd *cobra.Command, _ []string) error {
		cache, err := os.UserCacheDir()
		if err != nil {
			return err
		}
		base := filepath.Join(cache, "airgap-dev-kit", "releases")
		matches, err := filepath.Glob(filepath.Join(base, "*.part"))
		if err != nil {
			return err
		}
		for _, path := range matches {
			if dryRun {
				fmt.Fprintln(cmd.OutOrStdout(), "would remove "+path)
				continue
			}
			if !yes {
				return fmt.Errorf("clean requires --yes unless --dry-run is used")
			}
			if err := os.Remove(path); err != nil {
				return err
			}
		}
		if len(matches) == 0 {
			fmt.Fprintln(cmd.OutOrStdout(), "No interrupted release downloads found.")
		} else if !dryRun {
			fmt.Fprintf(cmd.OutOrStdout(), "Removed %d interrupted release download(s).\n", len(matches))
		}
		return nil
	}}
	c.Flags().BoolVar(&dryRun, "dry-run", false, "Print files that would be removed")
	c.Flags().BoolVar(&yes, "yes", false, "Confirm cleanup")
	return c
}

func completionCmd(root *cobra.Command) *cobra.Command {
	return &cobra.Command{Use: "completion [bash|zsh|fish|powershell]", Short: "Generate shell completion", Args: cobra.ExactArgs(1), RunE: func(cmd *cobra.Command, a []string) error {
		switch a[0] {
		case "bash":
			return root.GenBashCompletion(cmd.OutOrStdout())
		case "zsh":
			return root.GenZshCompletion(cmd.OutOrStdout())
		case "fish":
			return root.GenFishCompletion(cmd.OutOrStdout(), true)
		case "powershell":
			return root.GenPowerShellCompletion(cmd.OutOrStdout())
		default:
			return fmt.Errorf("unsupported shell %q", a[0])
		}
	}}
}

// aliasCmd preserves the indefinitely-supported historical command name.
func aliasCmd() *cobra.Command {
	return &cobra.Command{Use: "airgap-dev-kit", Hidden: true, Short: "Compatibility command alias"}
}

func kitRoot() (string, error) {
	if root, ok := discoveredKitRoot(); ok {
		return root, nil
	}
	return "", fmt.Errorf("cannot find kit root; run from an extracted kit or set AIRGAP_KIT_DIR")
}

func discoveredKitRoot() (string, bool) {
	if root := os.Getenv("AIRGAP_KIT_DIR"); isKitRoot(root) {
		return root, true
	}
	exe, err := os.Executable()
	if err == nil {
		root := filepath.Dir(filepath.Dir(exe))
		if isKitRoot(root) {
			return root, true
		}
	}
	if cwd, err := os.Getwd(); err == nil {
		if isKitRoot(cwd) {
			return cwd, true
		}
	}
	if state, err := loadUpdateState(); err == nil && isKitRoot(state.KitDir) {
		return state.KitDir, true
	}
	return "", false
}

func isKitRoot(root string) bool {
	if root == "" {
		return false
	}
	info, err := os.Stat(filepath.Join(root, "install.sh"))
	return err == nil && !info.IsDir()
}

func jsonOrText(cmd *cobra.Command, value any, text string) error {
	if viper.GetString("output") == "json" {
		b, err := json.Marshal(value)
		if err != nil {
			return err
		}
		_, err = fmt.Fprintln(cmd.OutOrStdout(), string(b))
		return err
	}
	if viper.GetString("output") != "text" {
		return fmt.Errorf("unsupported output format %q", viper.GetString("output"))
	}
	return writeStyledText(cmd, cmd.OutOrStdout(), text)
}

func isPrerelease(version string) bool { return strings.Contains(version, "-") }
