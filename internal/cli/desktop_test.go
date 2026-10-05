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
