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
