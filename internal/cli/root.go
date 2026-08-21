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
	root.AddCommand(versionCmd(version, commit), statusCmd(&output), doctorCmd(&output))
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
		root, err := kitRoot()
		if err != nil {
			return err
		}
		return jsonOrText(cmd, map[string]string{"kit_dir": root, "target": runtime.GOOS + "/" + runtime.GOARCH}, fmt.Sprintf("Kit directory: %s\nTarget: %s/%s\n", root, runtime.GOOS, runtime.GOARCH))
	}}
}

func doctorCmd(output *string) *cobra.Command {
	var strict, verify bool
	c := &cobra.Command{Use: "doctor", Short: "Diagnose an installed kit without network access", RunE: func(cmd *cobra.Command, _ []string) error {
		root, err := kitRoot()
		if err != nil {
			return err
		}
		_, versionErr := os.Stat(filepath.Join(root, "VERSION"))
		_, payloadErr := os.Stat(filepath.Join(root, "offline-packages", "linux", "amd64"))
		// v2 packages use amd64; existing packages are reported, not rejected.
		legacy := false
		if os.IsNotExist(payloadErr) {
			_, payloadErr = os.Stat(filepath.Join(root, "offline-packages", "linux"))
			legacy = payloadErr == nil
		}
		ok := versionErr == nil && payloadErr == nil
		data := map[string]any{"kit_dir": root, "version_file": versionErr == nil, "payload_present": payloadErr == nil, "legacy_payload_layout": legacy}
		text := fmt.Sprintf("Kit directory: %s\nVERSION: %t\nPayload: %t\n", root, versionErr == nil, payloadErr == nil)
		if err := jsonOrText(cmd, data, text); err != nil {
			return err
		}
		if strict && !ok {
			return fmt.Errorf("doctor found missing required kit files")
		}
		if verify && !ok {
			return fmt.Errorf("cannot verify incomplete payload")
		}
		return nil
	}}
	c.Flags().BoolVar(&strict, "strict", false, "Fail if a required kit file is missing")
	c.Flags().BoolVar(&verify, "verify", false, "Verify local kit prerequisites")
	return c
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
	exe, err := os.Executable()
	if err != nil {
		return "", err
	}
	root := filepath.Dir(filepath.Dir(exe))
	if _, err := os.Stat(filepath.Join(root, "install.sh")); err == nil {
		return root, nil
	}
	if cwd, err := os.Getwd(); err == nil {
		if _, err := os.Stat(filepath.Join(cwd, "install.sh")); err == nil {
			return cwd, nil
		}
	}
	return "", fmt.Errorf("cannot find kit root; run from an extracted kit")
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
