package cli

import (
	"encoding/json"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"github.com/spf13/cobra"
)

type installRecord struct {
	Version  string   `json:"version"`
	KitDir   string   `json:"kit_dir"`
	Paths    []string `json:"paths"`
	ShellRCs []string `json:"shell_rcs"`
}

type installOptions struct {
	DryRun         bool
	Yes            bool
	CLIOnly        bool
	NvimMode       string
	ConfigureShell bool
}

// installCmd installs only the payload in an extracted v2 kit. It deliberately
// has no network or shell-script dependency.
func installCmd() *cobra.Command {
	var options installOptions
	c := &cobra.Command{Use: "install", Short: "Install this extracted kit without network access", RunE: func(cmd *cobra.Command, _ []string) error {
		return installKit(cmd, options)
	}}
	c.Flags().BoolVarP(&options.DryRun, "dry-run", "n", false, "Show the plan without changing files")
	c.Flags().BoolVarP(&options.Yes, "yes", "y", false, "Confirm a non-interactive install")
	c.Flags().BoolVar(&options.CLIOnly, "cli-only", false, "Skip GUI payloads and fonts")
	c.Flags().StringVar(&options.NvimMode, "nvim-mode", "preserve", "Neovim state handling: preserve, replace, or overwrite")
	c.Flags().BoolVar(&options.ConfigureShell, "configure-shell", true, "Add an idempotent Airgap block to Bash or Zsh")
	return c
}

func uninstallCmd() *cobra.Command {
	var dryRun, yes bool
	c := &cobra.Command{Use: "uninstall", Short: "Uninstall only paths recorded by airgap", RunE: func(cmd *cobra.Command, _ []string) error {
		if !dryRun && !yes {
			return fmt.Errorf("uninstall requires --yes unless --dry-run is used")
		}
		return uninstallRecorded(cmd, dryRun)
	}}
	c.Flags().BoolVarP(&dryRun, "dry-run", "n", false, "Show tracked paths without changing files")
	c.Flags().BoolVarP(&yes, "yes", "y", false, "Confirm removal of tracked paths")
	return c
}

func installKit(cmd *cobra.Command, options installOptions) error {
	if options.NvimMode != "preserve" && options.NvimMode != "replace" && options.NvimMode != "overwrite" {
		return fmt.Errorf("unsupported --nvim-mode %q; use preserve, replace, or overwrite", options.NvimMode)
	}
	root, err := kitRoot()
	if err != nil {
		return err
	}
	manifest, payload, err := readKitManifest(root)
	if err != nil {
		return err
	}
	if manifest.Target != "linux/amd64" {
		return fmt.Errorf("kit target %q is not supported by this installer", manifest.Target)
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return err
	}
	binDir := filepath.Join(home, ".local", "bin")
	dataHome := os.Getenv("XDG_DATA_HOME")
	if dataHome == "" {
		dataHome = filepath.Join(home, ".local", "share")
	}
	paths := installPlan(root, payload, binDir, dataHome, options)
	if options.DryRun {
		fmt.Fprintln(cmd.OutOrStdout(), "Airgap install (dry run)")
		for _, path := range paths {
			fmt.Fprintln(cmd.OutOrStdout(), "  would install "+path)
		}
		return nil
	}
	if !options.Yes {
		if !wantsTUI(nil) {
			return fmt.Errorf("install requires --yes when input is not interactive")
		}
		planned, confirmed, err := planInstall(cmd, options, nvimStateExists(home, dataHome))
		if err != nil {
			return err
		}
		if !confirmed {
			fmt.Fprintln(cmd.OutOrStdout(), "Install cancelled.")
			return nil
		}
		options = planned
	}

	fmt.Fprintln(cmd.OutOrStdout(), styled(cmd, titleStyle, "Airgap install"))
	fmt.Fprintln(cmd.OutOrStdout(), styled(cmd, dimStyle, "Offline payload · user-local installation"))
	record := installRecord{Version: manifest.Version, KitDir: root}
	installNvim := options.NvimMode == "replace" || options.NvimMode == "overwrite" || !nvimStateExists(home, dataHome)
	steps := []installStep{
		{label: "Prepare user-local directories", result: "Installed", details: "Created ~/.local/bin", action: func() error {
			return os.MkdirAll(binDir, 0755)
		}},
		{label: "Copy command-line payload", result: "Installed", details: "Offline binaries copied to ~/.local/bin", action: func() error {
			return copyPayloadBinaries(payload, binDir, options.CLIOnly, &record)
		}},
	}
	if installNvim {
		steps = append(steps, installStep{label: "Install Neovim and editor payload", result: "Installed", details: "Bundled Neovim, LazyVim, and Mason payload", action: func() error {
			return installNvimPayload(root, payload, home, dataHome, options.NvimMode, &record)
		}})
	} else {
		steps = append(steps, installStep{label: "Keep existing Neovim profile", result: "Preserved", details: "No Neovim files were changed", action: func() error { return nil }})
	}
	steps = append(steps,
		installStep{label: "Install managed configuration", result: "Installed", details: "User configuration copied safely", action: func() error {
			return copyManagedConfig(root, home, installNvim, &record)
		}},
		installStep{label: "Install FZF shell integration", result: "Installed", details: "Bundled FZF shell helpers", action: func() error {
			return installFZFIntegration(payload, home, &record)
		}},
	)
	if options.ConfigureShell {
		steps = append(steps, installStep{label: "Configure Bash and Zsh", result: "Installed", details: "Managed, removable shell integration", action: func() error {
			return configureShells(home, &record)
		}})
	} else {
		steps = append(steps, installStep{label: "Leave shell startup files unchanged", result: "Skipped", details: "Shell integration was declined", action: func() error { return nil }})
	}
	steps = append(steps, installStep{label: "Save installation record", result: "Installed", details: "Safe uninstall record written", action: func() error {
		return saveInstallRecord(record)
	}})
	if wantsTUI(nil) && !options.Yes {
		if err := runInstallProgress(cmd, steps); err != nil {
			return err
		}
	} else if err := runInstallText(cmd, steps); err != nil {
		return err
	}
	fmt.Fprintln(cmd.OutOrStdout(), styled(cmd, okStyle, "✓ Installed offline kit payload"))
	fmt.Fprintln(cmd.OutOrStdout(), "  Binaries: "+styled(cmd, pathStyle, binDir))
	if installNvim {
		fmt.Fprintln(cmd.OutOrStdout(), "  Neovim: "+styled(cmd, pathStyle, filepath.Join(binDir, "nvim")))
	}
	fmt.Fprintln(cmd.OutOrStdout(), "  Next: restart your shell, then run airgap status")
	return nil
}

func installFZFIntegration(payload, home string, record *installRecord) error {
	source := filepath.Join(payload, "fzf-scripts")
	if _, err := os.Stat(source); os.IsNotExist(err) {
		return nil
	} else if err != nil {
		return err
	}
	destination := filepath.Join(home, ".fzf", "shell")
	if err := copyTree(source, destination); err != nil {
		return err
	}
	return filepath.WalkDir(destination, func(path string, entry fs.DirEntry, err error) error {
		if err == nil && !entry.IsDir() {
			record.Paths = append(record.Paths, path)
		}
		return err
	})
}

const shellBlockStart = "# >>> airgap dev kit >>>"
const shellBlockEnd = "# <<< airgap dev kit <<<"

func configureShells(home string, record *installRecord) error {
	shellFile := filepath.Join(home, ".config", "airgap-dev-kit", "shell.sh")
	if err := writeAirgapShellFile(shellFile); err != nil {
		return err
	}
	record.Paths = append(record.Paths, shellFile)
	rcs := []string{filepath.Join(home, ".bashrc"), filepath.Join(home, ".zshrc")}
	found := false
	for _, rc := range rcs {
		if _, err := os.Stat(rc); err == nil {
			found = true
			if err := writeShellBlock(rc, shellFile); err != nil {
				return err
			}
			record.ShellRCs = append(record.ShellRCs, rc)
		}
	}
	if found {
		return nil
	}
	path := rcs[0]
	if filepath.Base(os.Getenv("SHELL")) == "zsh" {
		path = rcs[1]
	}
	if err := writeShellBlock(path, shellFile); err != nil {
		return err
	}
	record.ShellRCs = append(record.ShellRCs, path)
	return nil
}

func writeShellBlock(path, shellFile string) error {
	raw, err := os.ReadFile(path)
	if err != nil && !os.IsNotExist(err) {
		return err
	}
	content := removeShellBlock(string(raw))
	block := shellBlockStart + "\n. \"" + shellFile + "\"\n" + shellBlockEnd + "\n"
	if content != "" && !strings.HasSuffix(content, "\n") {
		content += "\n"
	}
	return writeAtomic(path, []byte(content+"\n"+block), 0644)
}

func writeAirgapShellFile(path string) error {
	content := "# Managed by airgap. Source this file; do not edit the RC block.\n" +
		"export PATH=\"$HOME/.local/bin:$PATH\"\n" +
		"export EDITOR=nvim\n" +
		"alias vim=nvim\n" +
		"alias vi=nvim\n" +
		"[ -x \"$HOME/.local/bin/lsd\" ] && alias ls='lsd' && alias ll='lsd -la'\n" +
		"[ -x \"$HOME/.local/bin/bat\" ] && alias cat='bat --paging=never'\n" +
		"if [ -n \"${ZSH_VERSION:-}\" ]; then _airgap_shell=zsh; else _airgap_shell=bash; fi\n" +
		"[ -f \"$HOME/.fzf/shell/key-bindings.${_airgap_shell}\" ] && . \"$HOME/.fzf/shell/key-bindings.${_airgap_shell}\"\n" +
		"[ -f \"$HOME/.fzf/shell/completion.${_airgap_shell}\" ] && . \"$HOME/.fzf/shell/completion.${_airgap_shell}\"\n" +
		"command -v starship >/dev/null 2>&1 && eval \"$(starship init \"${_airgap_shell}\")\"\n" +
		"command -v zoxide >/dev/null 2>&1 && eval \"$(zoxide init \"${_airgap_shell}\")\"\n" +
		"unset _airgap_shell\n"
	return writeAtomic(path, []byte(content), 0644)
}

func removeShellBlock(content string) string {
	start := strings.Index(content, shellBlockStart)
	if start < 0 {
		return content
	}
	endOffset := strings.Index(content[start:], shellBlockEnd)
	if endOffset < 0 {
		return content
	}
	end := start + endOffset + len(shellBlockEnd)
	if end < len(content) && content[end] == '\n' {
		end++
	}
	return strings.TrimRight(content[:start]+content[end:], "\n") + "\n"
}

func readKitManifest(root string) (kitManifest, string, error) {
	raw, err := os.ReadFile(filepath.Join(root, "kit-manifest.json"))
	if os.IsNotExist(err) {
		payload := filepath.Join(root, "offline-packages", "linux")
		if info, statErr := os.Stat(payload); statErr == nil && info.IsDir() {
			return kitManifest{SchemaVersion: 1, Version: "dev", Target: "linux/amd64", PayloadDir: "offline-packages/linux"}, payload, nil
		}
	}
	if err != nil {
		return kitManifest{}, "", fmt.Errorf("read kit manifest: %w", err)
	}
	var manifest kitManifest
	if err := json.Unmarshal(raw, &manifest); err != nil || manifest.SchemaVersion != 1 || manifest.PayloadDir == "" || filepath.IsAbs(manifest.PayloadDir) || strings.HasPrefix(filepath.Clean(manifest.PayloadDir), "..") {
		return kitManifest{}, "", fmt.Errorf("kit-manifest.json is invalid")
	}
	payload := filepath.Join(root, manifest.PayloadDir)
	if info, err := os.Stat(payload); err != nil || !info.IsDir() {
		return kitManifest{}, "", fmt.Errorf("kit payload is missing: %s", payload)
	}
	return manifest, payload, nil
}

func installPlan(root, payload, binDir, dataHome string, options installOptions) []string {
	paths := []string{binDir}
	entries, _ := os.ReadDir(payload)
	for _, entry := range entries {
		if entry.IsDir() || entry.Name() == "nvim-static-x86_64" || entry.Name() == "airgap-dev-kit" || (options.CLIOnly && entry.Name() == "wezterm.AppImage") {
			continue
		}
		paths = append(paths, filepath.Join(binDir, entry.Name()))
	}
	paths = append(paths, filepath.Join(binDir, "nvim"), filepath.Join(binDir, "nvim-airgap"))
	paths = append(paths, filepath.Join(dataHome, "nvim", "runtime"), "~/.config/nvim")
	return paths
}

func copyPayloadBinaries(payload, binDir string, cliOnly bool, record *installRecord) error {
	entries, err := os.ReadDir(payload)
	if err != nil {
		return err
	}
	for _, entry := range entries {
		if entry.IsDir() || entry.Name() == "nvim-static-x86_64" || entry.Name() == "airgap-dev-kit" || (cliOnly && entry.Name() == "wezterm.AppImage") {
			continue
		}
		info, err := entry.Info()
		if err != nil || !info.Mode().IsRegular() {
			continue
		}
		name := entry.Name()
		if name == "wezterm.AppImage" {
			name = "wezterm"
		}
		if err := copyExecutable(filepath.Join(payload, entry.Name()), filepath.Join(binDir, name)); err != nil {
			return err
		}
		record.Paths = append(record.Paths, filepath.Join(binDir, name))
	}
	return nil
}

func installNvimPayload(root, payload, home, dataHome, mode string, record *installRecord) error {
	paths := nvimProfilePaths(home, dataHome)
	if mode == "replace" {
		backup := filepath.Join(dataHome, "airgap-dev-kit", "backups", "nvim-"+time.Now().UTC().Format("20060102-150405"))
		for _, path := range paths {
			if _, err := os.Lstat(path); err == nil {
				destination := filepath.Join(backup, strings.TrimPrefix(path, home+string(filepath.Separator)))
				if err := os.MkdirAll(filepath.Dir(destination), 0700); err != nil {
					return err
				}
				if err := os.Rename(path, destination); err != nil {
					return fmt.Errorf("back up %s: %w", path, err)
				}
			}
		}
	} else if mode == "overwrite" {
		for _, path := range paths {
			if err := os.RemoveAll(path); err != nil {
				return fmt.Errorf("delete %s: %w", path, err)
			}
		}
	}
	binDir := filepath.Join(home, ".local", "bin")
	if err := copyExecutable(filepath.Join(payload, "nvim-static-x86_64"), filepath.Join(binDir, "nvim-airgap")); err != nil {
		return err
	}
	record.Paths = append(record.Paths, filepath.Join(binDir, "nvim-airgap"))
	runtimeDestination := filepath.Join(dataHome, "nvim", "runtime")
	if err := copyTree(filepath.Join(payload, "nvim-runtime"), runtimeDestination); err != nil {
		return err
	}
	if _, err := os.Stat(filepath.Join(runtimeDestination, "syntax", "syntax.vim")); err != nil {
		return fmt.Errorf("bundled Neovim runtime is incomplete: %w", err)
	}
	record.Paths = append(record.Paths, runtimeDestination)
	launcher := "#!/bin/sh\nset -eu\nexport VIMRUNTIME=\"${XDG_DATA_HOME:-$HOME/.local/share}/nvim/runtime\"\nexec \"" + filepath.Join(binDir, "nvim-airgap") + "\" \"$@\"\n"
	if err := writeAtomic(filepath.Join(binDir, "nvim"), []byte(launcher), 0755); err != nil {
		return err
	}
	record.Paths = append(record.Paths, filepath.Join(binDir, "nvim"))
	for _, archive := range []struct{ file, directory string }{{"lazy-plugins.tar.gz", "lazy"}, {"mason-lsp.tar.gz", "mason"}} {
		path := filepath.Join(root, "offline-packages", archive.file)
		if _, err := os.Stat(path); err == nil {
			destination := filepath.Join(dataHome, "nvim", archive.directory)
			if err := extractPayloadDirectory(path, archive.directory, destination); err != nil {
				return err
			}
			record.Paths = append(record.Paths, destination)
		}
	}
	return nil
}

func nvimStateExists(home, dataHome string) bool {
	for _, path := range nvimProfilePaths(home, dataHome) {
		if _, err := os.Lstat(path); err == nil {
			return true
		}
	}
	return false
}

func nvimProfilePaths(home, dataHome string) []string {
	return []string{filepath.Join(home, ".config", "nvim"), filepath.Join(dataHome, "nvim"), filepath.Join(home, ".local", "state", "nvim"), filepath.Join(home, ".cache", "nvim")}
}

func copyManagedConfig(root, home string, nvim bool, record *installRecord) error {
	configRoot := filepath.Join(root, "config")
	packages, err := os.ReadDir(configRoot)
	if err != nil {
		return err
	}
	for _, pkg := range packages {
		if !pkg.IsDir() || (pkg.Name() == "nvim" && !nvim) {
			continue
		}
		if err := filepath.WalkDir(filepath.Join(configRoot, pkg.Name()), func(path string, entry fs.DirEntry, walkErr error) error {
			if walkErr != nil {
				return walkErr
			}
			rel, err := filepath.Rel(filepath.Join(configRoot, pkg.Name()), path)
			if err != nil || rel == "." {
				return err
			}
			destination := filepath.Join(home, rel)
			if entry.IsDir() {
				return os.MkdirAll(destination, 0755)
			}
			if !entry.Type().IsRegular() {
				return nil
			}
			if err := copyFile(path, destination, 0644); err != nil {
				return err
			}
			record.Paths = append(record.Paths, destination)
			return nil
		}); err != nil {
			return err
		}
	}
	return nil
}

func copyExecutable(source, destination string) error { return copyFile(source, destination, 0755) }

func copyFile(source, destination string, mode fs.FileMode) error {
	in, err := os.Open(source)
	if err != nil {
		return err
	}
	defer in.Close()
	if err := os.MkdirAll(filepath.Dir(destination), 0755); err != nil {
		return err
	}
	temp := destination + ".airgap-tmp"
	out, err := os.OpenFile(temp, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, mode)
	if err != nil {
		return err
	}
	_, copyErr := io.Copy(out, in)
	closeErr := out.Close()
	if copyErr != nil {
		return copyErr
	}
	if closeErr != nil {
		return closeErr
	}
	return os.Rename(temp, destination)
}

func writeAtomic(destination string, data []byte, mode fs.FileMode) error {
	if err := os.MkdirAll(filepath.Dir(destination), 0755); err != nil {
		return err
	}
	temp := destination + ".airgap-tmp"
	if err := os.WriteFile(temp, data, mode); err != nil {
		return err
	}
	return os.Rename(temp, destination)
}

func copyTree(source, destination string) error {
	return filepath.WalkDir(source, func(path string, entry fs.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		rel, err := filepath.Rel(source, path)
		if err != nil {
			return err
		}
		target := filepath.Join(destination, rel)
		if entry.IsDir() {
			return os.MkdirAll(target, 0755)
		}
		if !entry.Type().IsRegular() {
			return fmt.Errorf("unsupported payload entry %s", path)
		}
		return copyFile(path, target, 0644)
	})
}

func extractPayloadDirectory(archive, directory, destination string) error {
	stage, err := os.MkdirTemp(filepath.Dir(destination), ".airgap-extract-")
	if err != nil {
		return err
	}
	defer os.RemoveAll(stage)
	if err := extractSafeTarGz(archive, stage); err != nil {
		return err
	}
	source := filepath.Join(stage, directory)
	if info, err := os.Stat(source); err != nil || !info.IsDir() {
		return fmt.Errorf("%s has no %s directory", archive, directory)
	}
	_ = os.RemoveAll(destination)
	return os.Rename(source, destination)
}

func installRecordPath() (string, error) {
	state := os.Getenv("XDG_STATE_HOME")
	if state == "" {
		home, err := os.UserHomeDir()
		if err != nil {
			return "", err
		}
		state = filepath.Join(home, ".local", "state")
	}
	return filepath.Join(state, "airgap-dev-kit", "install.json"), nil
}

func saveInstallRecord(record installRecord) error {
	sort.Strings(record.Paths)
	path, err := installRecordPath()
	if err != nil {
		return err
	}
	raw, err := json.Marshal(record)
	if err != nil {
		return err
	}
	return writeAtomic(path, raw, 0600)
}

func uninstallRecorded(cmd *cobra.Command, dryRun bool) error {
	path, err := installRecordPath()
	if err != nil {
		return err
	}
	raw, err := os.ReadFile(path)
	if os.IsNotExist(err) {
		fmt.Fprintln(cmd.OutOrStdout(), "No native airgap installation record found.")
		return nil
	}
	if err != nil {
		return err
	}
	var record installRecord
	if err := json.Unmarshal(raw, &record); err != nil {
		return err
	}
	for index := len(record.Paths) - 1; index >= 0; index-- {
		item := record.Paths[index]
		if dryRun {
			fmt.Fprintln(cmd.OutOrStdout(), "would remove "+item)
			continue
		}
		if err := os.RemoveAll(item); err != nil && !os.IsNotExist(err) {
			return err
		}
		fmt.Fprintln(cmd.OutOrStdout(), "removed "+item)
	}
	for _, rc := range record.ShellRCs {
		if dryRun {
			fmt.Fprintln(cmd.OutOrStdout(), "would remove Airgap block from "+rc)
			continue
		}
		raw, err := os.ReadFile(rc)
		if err != nil && !os.IsNotExist(err) {
			return err
		}
		if err == nil && writeAtomic(rc, []byte(removeShellBlock(string(raw))), 0644) != nil {
			return err
		}
	}
	if !dryRun {
		return os.Remove(path)
	}
	return nil
}
