package cli

import (
	"bytes"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
)

func TestWezLaunchPresets(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_STATE_HOME", filepath.Join(home, ".local", "state"))
	kit := t.TempDir()
	t.Setenv("AIRGAP_KIT_DIR", kit)
	config := filepath.Join(kit, "config", "wezterm", ".config", "wezterm", "wezterm.lua")
	if err := os.MkdirAll(filepath.Dir(config), 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(kit, "kit-manifest.json"), []byte(`{}`), 0644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(config, []byte("return {}"), 0644); err != nil {
		t.Fatal(err)
	}
	for _, preset := range []string{"current", "kit", "plain", "x11"} {
		t.Run(preset, func(t *testing.T) {
			args, err := wezPresetArgs(preset)
			if err != nil {
				t.Fatal(err)
			}
			if !reflect.DeepEqual(args[len(args)-2:], []string{"start", "--always-new-process"}) {
				t.Fatal(args)
			}
			if preset == "plain" && args[0] != "--skip-config" {
				t.Fatal(args)
			}
			if preset == "x11" && !strings.Contains(strings.Join(args, " "), "--config enable_wayland=false") {
				t.Fatal(args)
			}
		})
	}
	if _, err := wezPresetArgs("../../bad"); err == nil {
		t.Fatal("unknown preset accepted")
	}
}

func TestWezInstalledPresetsWithoutExtractedKit(t *testing.T) {
	home := filepath.Join(t.TempDir(), "home with spaces")
	t.Setenv("HOME", home)
	t.Setenv("XDG_STATE_HOME", filepath.Join(home, ".local", "state"))
	t.Setenv("AIRGAP_KIT_DIR", "")
	t.Chdir(t.TempDir())
	_, appData := installLocations(home, "user")
	preset := filepath.Join(appData, "wezterm-preset.lua")
	if err := os.MkdirAll(appData, 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(preset, []byte("return {}"), 0644); err != nil {
		t.Fatal(err)
	}
	kit := t.TempDir()
	if err := saveInstallRecord(installRecord{Scope: "user", KitDir: kit, Paths: []string{preset}}); err != nil {
		t.Fatal(err)
	}
	if err := os.RemoveAll(kit); err != nil {
		t.Fatal(err)
	}
	personal := filepath.Join(home, ".wezterm.lua")
	if err := os.WriteFile(personal, []byte("personal config"), 0644); err != nil {
		t.Fatal(err)
	}
	bin := t.TempDir()
	if err := os.WriteFile(filepath.Join(bin, "wezterm"), []byte("#!/bin/sh\nprintf '%s\\n' \"$@\"\n"), 0755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", bin)
	for _, name := range []string{"current", "kit", "plain", "x11"} {
		t.Run(name, func(t *testing.T) {
			root := New("test", "test")
			var output bytes.Buffer
			root.SetOut(&output)
			root.SetArgs([]string{"wez", "start", name})
			if err := root.Execute(); err != nil {
				t.Fatal(err)
			}
			if (name == "kit" || name == "x11") && !strings.HasPrefix(output.String(), "--config-file\n"+preset+"\n") {
				t.Fatalf("managed preset path was not passed as one argument: %q", output.String())
			}
			data, err := os.ReadFile(personal)
			if err != nil || string(data) != "personal config" {
				t.Fatalf("personal config changed: %q %v", data, err)
			}
		})
	}
	if err := saveInstallRecord(installRecord{Scope: "user", KitDir: kit}); err != nil {
		t.Fatal(err)
	}
	if _, found := installedWezPresetPath(); found {
		t.Fatal("untracked preset was accepted")
	}
	if err := saveInstallRecord(installRecord{Scope: "user", KitDir: kit, Paths: []string{preset}}); err != nil {
		t.Fatal(err)
	}
	if err := os.Remove(preset); err != nil {
		t.Fatal(err)
	}
	if _, found := installedWezPresetPath(); found {
		t.Fatal("missing managed preset was accepted")
	}
}

func TestWezStartsExecutableWithoutChangingConfig(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	config := filepath.Join(home, ".wezterm.lua")
	if err := os.WriteFile(config, []byte("personal config"), 0644); err != nil {
		t.Fatal(err)
	}
	bin := t.TempDir()
	if err := os.WriteFile(filepath.Join(bin, "wezterm"), []byte("#!/bin/sh\nprintf '%s\\n' \"$@\"\n"), 0755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", bin)
	root := New("test", "test")
	var output bytes.Buffer
	root.SetOut(&output)
	root.SetArgs([]string{"wez", "start", "plain"})
	if err := root.Execute(); err != nil {
		t.Fatal(err)
	}
	if output.String() != "--skip-config\nstart\n--always-new-process\n" {
		t.Fatal(output.String())
	}
	data, err := os.ReadFile(config)
	if err != nil || string(data) != "personal config" {
		t.Fatalf("config changed: %q %v", data, err)
	}
}
