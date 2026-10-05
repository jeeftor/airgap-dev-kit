package cli

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

func desktopHostDescription() string {
	distribution := "Linux"
	for _, path := range []string{"/etc/os-release", "/usr/lib/os-release"} {
		if raw, err := os.ReadFile(path); err == nil {
			distribution = distributionName(string(raw))
			break
		}
	}
	desktop := os.Getenv("XDG_CURRENT_DESKTOP")
	if desktop == "" {
		desktop = os.Getenv("DESKTOP_SESSION")
	}
	if desktop == "" {
		return distribution + " · no desktop session detected"
	}
	return distribution + " · " + desktop
}

func distributionName(raw string) string {
	values := desktopConfigValues(raw)
	if values["PRETTY_NAME"] != "" {
		return values["PRETTY_NAME"]
	}
	name := values["NAME"]
	if name == "" {
		name = values["ID"]
	}
	if name == "" {
		return "Linux"
	}
	return strings.TrimSpace(name + " " + values["VERSION_ID"])
}

// desktopConfigValues reads assignments without executing shell configuration.
func desktopConfigValues(raw string) map[string]string {
	values := make(map[string]string)
	for _, line := range strings.Split(raw, "\n") {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, "#") {
			continue
		}
		key, value, ok := strings.Cut(line, "=")
		if ok {
			values[strings.TrimSpace(key)] = strings.Trim(strings.TrimSpace(value), "\"'")
		}
	}
	return values
}

func userDesktopDirectory(home string) (string, error) {
	configHome := os.Getenv("XDG_CONFIG_HOME")
	if configHome == "" {
		configHome = filepath.Join(home, ".config")
	}
	path := filepath.Join(home, "Desktop")
	if raw, err := os.ReadFile(filepath.Join(configHome, "user-dirs.dirs")); err == nil {
		if configured := desktopConfigValues(string(raw))["XDG_DESKTOP_DIR"]; configured != "" {
			path = configured
			if path == "$HOME" || strings.HasPrefix(path, "$HOME/") {
				path = home + strings.TrimPrefix(path, "$HOME")
			}
		}
	} else if !os.IsNotExist(err) {
		return "", fmt.Errorf("read your desktop directory configuration: %w", err)
	}
	if !filepath.IsAbs(path) || filepath.Clean(path) == filepath.Clean(home) {
		return "", fmt.Errorf("your desktop directory is disabled or invalid; choose applications-menu integration instead")
	}
	return filepath.Clean(path), nil
}

func wezTermDesktopEntry(binDir string) []byte {
	executable := filepath.Join(binDir, "wezterm")
	// Desktop entries have separate string and command-line escaping rules.
	executable = strings.NewReplacer("\\", "\\\\", "\"", "\\\"", "`", "\\`", "$", "\\$", "%", "%%").Replace(executable)
	executable = strings.ReplaceAll(executable, "\\", "\\\\")
	return []byte("[Desktop Entry]\nType=Application\nName=WezTerm (Airgap)\nComment=Your offline terminal\n" +
		"Exec=\"" + executable + "\" start\nIcon=utilities-terminal\nTerminal=false\nCategories=System;TerminalEmulator;\n")
}

func installWezTermDesktop(binDir, menuPath, shortcutPath, scope string, record *installRecord) error {
	entry := wezTermDesktopEntry(binDir)
	if err := writeFileForScope(menuPath, entry, 0644, scope); err != nil {
		return err
	}
	record.Paths = append(record.Paths, menuPath)
	if shortcutPath != "" {
		if err := writeFileForScope(shortcutPath, entry, 0755, "user"); err != nil {
			return err
		}
		record.Paths = append(record.Paths, shortcutPath)
	}
	return nil
}

func guiSelected(options installOptions) bool {
	return !options.CLIOnly && (options.Tools == nil || options.Tools["wezterm"])
}

func desktopIntegrationPaths(home, dataHome string, options installOptions) (string, string, error) {
	if !guiSelected(options) || options.DesktopIntegration == "none" {
		return "", "", nil
	}
	menu := filepath.Join(dataHome, "applications", "airgap-wezterm.desktop")
	if options.Scope == "system" {
		menu = "/usr/local/share/applications/airgap-wezterm.desktop"
	}
	if options.DesktopIntegration != "menu-and-desktop" {
		return menu, "", nil
	}
	desktop, err := userDesktopDirectory(home)
	if err != nil {
		return "", "", err
	}
	return menu, filepath.Join(desktop, "airgap-wezterm.desktop"), nil
}
