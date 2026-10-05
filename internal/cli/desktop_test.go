package cli

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestWezTermApplicationLauncherIsInstalledAndRemoved(t *testing.T) {
	home := filepath.Join(t.TempDir(), "your home")
	t.Setenv("HOME", home)
	t.Setenv("XDG_STATE_HOME", filepath.Join(home, ".local", "state"))
	source := filepath.Join(t.TempDir(), "wezterm.AppImage")
	if err := os.WriteFile(source, []byte("#!/bin/sh\nexit 0\n"), 0755); err != nil {
		t.Fatal(err)
	}
	bin, data := installLocations(home, "user")
	record := installRecord{Version: "v0.0.0", Scope: "user"}
	if err := installWezTermAppImage(source, bin, data, "user", &record); err != nil {
		t.Fatal(err)
	}
	launcher := filepath.Join(home, ".local", "share", "applications", "airgap-wezterm.desktop")
	if err := installWezTermDesktop(bin, launcher, "", "user", &record); err != nil {
		t.Fatal(err)
	}
	content, err := os.ReadFile(launcher)
	if err != nil {
		t.Fatal(err)
	}
	for _, expected := range []string{"Name=WezTerm (Airgap)", "Exec=\"" + filepath.Join(bin, "wezterm") + "\" start", "Terminal=false"} {
		if !strings.Contains(string(content), expected) {
			t.Fatalf("application launcher is missing %q: %s", expected, content)
		}
	}
	if err := saveInstallRecord(record); err != nil {
		t.Fatal(err)
	}
	root := New("v0.0.0", "test")
	root.SetOut(&bytes.Buffer{})
	root.SetArgs([]string{"uninstall", "--yes"})
	if err := root.Execute(); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(launcher); !os.IsNotExist(err) {
		t.Fatalf("tracked application launcher was not removed: %v", err)
	}
}

func TestDistributionNameRecognizesMajorLinuxInstalls(t *testing.T) {
	for _, fixture := range []struct{ raw, want string }{
		{"ID=rhel\nPRETTY_NAME=\"Red Hat Enterprise Linux 10.0 (Coughlan)\"\n", "Red Hat Enterprise Linux 10.0 (Coughlan)"},
		{"ID=debian\nPRETTY_NAME=\"Debian GNU/Linux 13 (trixie)\"\n", "Debian GNU/Linux 13 (trixie)"},
		{"ID=ubuntu\nPRETTY_NAME=\"Ubuntu 26.04 LTS\"\n", "Ubuntu 26.04 LTS"},
		{"NAME='Example Linux'\nVERSION_ID=10\n", "Example Linux 10"},
		{"# no identity\n", "Linux"},
	} {
		if got := distributionName(fixture.raw); got != fixture.want {
			t.Fatalf("distribution = %q, want %q", got, fixture.want)
		}
	}
}

func TestDesktopIntegrationHonorsScopeXDGPathsAndOptOut(t *testing.T) {
	home := t.TempDir()
	config := filepath.Join(home, "settings")
	t.Setenv("XDG_CONFIG_HOME", config)
	if err := os.MkdirAll(config, 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(config, "user-dirs.dirs"), []byte("XDG_DESKTOP_DIR=\"$HOME/Bureau personnel\"\n"), 0644); err != nil {
		t.Fatal(err)
	}
	data := filepath.Join(home, "custom-data")
	for _, fixture := range []struct {
		options        installOptions
		menu, shortcut string
	}{
		{installOptions{Scope: "user", DesktopIntegration: "menu"}, filepath.Join(data, "applications", "airgap-wezterm.desktop"), ""},
		{installOptions{Scope: "system", DesktopIntegration: "menu-and-desktop"}, "/usr/local/share/applications/airgap-wezterm.desktop", filepath.Join(home, "Bureau personnel", "airgap-wezterm.desktop")},
		{installOptions{Scope: "user", DesktopIntegration: "none"}, "", ""},
		{installOptions{Scope: "user", CLIOnly: true, DesktopIntegration: "menu-and-desktop"}, "", ""},
		{installOptions{Scope: "user", Tools: map[string]bool{"wezterm": false}, DesktopIntegration: "menu"}, "", ""},
	} {
		menu, shortcut, err := desktopIntegrationPaths(home, data, fixture.options)
		if err != nil || menu != fixture.menu || shortcut != fixture.shortcut {
			t.Fatalf("paths = %q, %q, %v; want %q, %q", menu, shortcut, err, fixture.menu, fixture.shortcut)
		}
	}
	if err := os.WriteFile(filepath.Join(config, "user-dirs.dirs"), []byte("XDG_DESKTOP_DIR=\"$HOME\"\n"), 0644); err != nil {
		t.Fatal(err)
	}
	if _, err := userDesktopDirectory(home); err == nil {
		t.Fatal("disabled desktop directory must not create a shortcut in your home root")
	}
}

func TestOptionalDesktopShortcutIsExecutableAndRemoved(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_STATE_HOME", filepath.Join(home, "state"))
	menu := filepath.Join(home, "data", "applications", "airgap-wezterm.desktop")
	shortcut := filepath.Join(home, "Your Desktop", "airgap-wezterm.desktop")
	record := installRecord{Scope: "user"}
	if err := installWezTermDesktop(filepath.Join(home, ".local", "bin"), menu, shortcut, "user", &record); err != nil {
		t.Fatal(err)
	}
	info, err := os.Stat(shortcut)
	if err != nil || info.Mode().Perm() != 0755 {
		t.Fatalf("desktop shortcut must be executable: %v, %v", info, err)
	}
	if err := saveInstallRecord(record); err != nil {
		t.Fatal(err)
	}
	root := New("test", "test")
	root.SetOut(&bytes.Buffer{})
	root.SetArgs([]string{"uninstall", "--yes"})
	if err := root.Execute(); err != nil {
		t.Fatal(err)
	}
	for _, path := range []string{menu, shortcut} {
		if _, err := os.Stat(path); !os.IsNotExist(err) {
			t.Fatalf("registered launcher was not removed: %s: %v", path, err)
		}
	}
}
