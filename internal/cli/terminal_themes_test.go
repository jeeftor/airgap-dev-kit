package cli

import (
	"bytes"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
	"testing"
)

func TestThemeSelectionAndReset(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_STATE_HOME", filepath.Join(home, "state"))
	record := installRecord{Scope: "user", Version: "test"}
	original := map[string]string{
		"kitty/kitty.conf":    "font_size 14\ncopy_on_select clipboard\n",
		"ghostty/config":      "font-size = 14\ncopy-on-select = clipboard\n",
		"wezterm/wezterm.lua": "local config = {}\nconfig.font_size = 14\nreturn config\n",
	}
	for relative, config := range original {
		path := filepath.Join(home, ".config", relative)
		if err := writeAtomic(path, []byte(config), 0644); err != nil {
			t.Fatal(err)
		}
		record.Paths = append(record.Paths, path)
	}
	if err := saveInstallRecord(record); err != nil {
		t.Fatal(err)
	}
	run := func(args ...string) string {
		t.Helper()
		command := New("test", "test")
		var output bytes.Buffer
		command.SetOut(&output)
		command.SetArgs(args)
		if err := command.Execute(); err != nil {
			t.Fatal(err)
		}
		return output.String()
	}
	listing := run("theme", "list")
	for _, name := range []string{"monokai", "midnight", "forest", "ember", "paper", "default"} {
		if !strings.Contains(listing, name) {
			t.Fatalf("theme missing from list: %s", name)
		}
	}
	run("theme", "set", "midnight", "--dry-run")
	for relative, config := range original {
		data, err := os.ReadFile(filepath.Join(home, ".config", relative))
		if err != nil || string(data) != config {
			t.Fatalf("dry run changed %s: %v", relative, err)
		}
	}
	for _, name := range []string{"monokai", "midnight", "forest", "ember", "paper", "default"} {
		run("theme", "set", name)
		for relative, config := range original {
			path := filepath.Join(home, ".config", relative)
			data, err := os.ReadFile(path)
			if err != nil || strings.Count(string(data), "Airgap terminal theme") != 1 {
				t.Fatalf("missing or duplicated include in %s: %v\n%s", relative, err, data)
			}
			if !strings.Contains(string(data), "14") || !strings.Contains(string(data), strings.Split(config, "\n")[0]) {
				t.Fatalf("theme changed unrelated settings: %s", data)
			}
			backups, err := filepath.Glob(path + ".airgap-theme-backup-*")
			if err != nil || len(backups) != 1 {
				t.Fatalf("expected one initial backup for %s, got %v: %v", relative, backups, err)
			}
			backup, err := os.ReadFile(backups[0])
			if err != nil || string(backup) != config {
				t.Fatalf("original settings were not backed up: %q %v", backup, err)
			}
			extension := ".conf"
			if strings.HasPrefix(relative, "wezterm/") {
				extension = ".lua"
			}
			colors, err := os.ReadFile(filepath.Join(filepath.Dir(path), "airgap-theme"+extension))
			if err != nil || !strings.Contains(string(colors), "Airgap theme: "+name+"\n") {
				t.Fatalf("wrong saved theme: %q %v", colors, err)
			}
			if strings.HasPrefix(relative, "wezterm/") {
				if lua, err := exec.LookPath("luajit"); err == nil {
					check := fmt.Sprintf("local config = dofile(%q); assert(config.font_size == 14);", path)
					if name != "default" {
						theme, _ := findTerminalTheme(name)
						check += fmt.Sprintf(" assert(config.colors.background == %q)", theme.Background)
					} else {
						check += " assert(config.colors == nil)"
					}
					if output, err := exec.Command(lua, "-e", check).CombinedOutput(); err != nil {
						t.Fatalf("generated Lua failed: %v\n%s", err, output)
					}
				}
			}
		}
	}
	run("uninstall", "--yes")
	for relative := range original {
		path := filepath.Join(home, ".config", relative)
		if _, err := os.Stat(path); !os.IsNotExist(err) {
			t.Fatalf("tracked config survived uninstall: %s, %v", path, err)
		}
		colors, err := filepath.Glob(filepath.Join(filepath.Dir(path), "airgap-theme.*"))
		if err != nil || len(colors) != 0 {
			t.Fatalf("theme survived uninstall: %v, %v", colors, err)
		}
		backups, _ := filepath.Glob(path + ".airgap-theme-backup-*")
		if len(backups) != 1 {
			t.Fatalf("uninstall removed original backup: %s", path)
		}
	}
}

func TestThemePreviewDoesNotSaveSettings(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_STATE_HOME", filepath.Join(home, "state"))
	bin := t.TempDir()
	for _, terminal := range []string{"kitty", "ghostty", "wezterm"} {
		script := "#!/bin/sh\nprintf '%s\\n' \"$@\"\n"
		if terminal == "ghostty" {
			script += "for arg do\ncase $arg in --config-file=*) /bin/cat \"${arg#--config-file=}\";; esac\ndone\n"
		}
		if err := os.WriteFile(filepath.Join(bin, terminal), []byte(script), 0755); err != nil {
			t.Fatal(err)
		}
	}
	t.Setenv("PATH", bin)
	for _, terminal := range []string{"kitty", "ghostty", "wezterm"} {
		command := New("test", "test")
		var output bytes.Buffer
		command.SetOut(&output)
		command.SetArgs([]string{"theme", "start", terminal, "paper"})
		if err := command.Execute(); err != nil {
			t.Fatal(err)
		}
		if !strings.Contains(output.String(), "#faf6ed") {
			t.Fatalf("preview did not pass Paper colors to %s: %s", terminal, output.String())
		}
		if terminal == "ghostty" {
			if !strings.Contains(output.String(), "--gtk-single-instance=false") {
				t.Fatal("preview could reuse an existing Ghostty instance")
			}
			for _, line := range strings.Split(output.String(), "\n") {
				if path, found := strings.CutPrefix(line, "--config-file="); found {
					if _, err := os.Stat(path); !os.IsNotExist(err) {
						t.Fatalf("temporary preview palette was not cleaned up: %s %v", path, err)
					}
				}
			}
		}
	}
	entries, err := os.ReadDir(home)
	if err != nil || len(entries) != 0 {
		t.Fatalf("preview changed saved settings: %v %v", entries, err)
	}
}

func TestMonokaiPresetDefaults(t *testing.T) {
	theme, err := findTerminalTheme("monokai")
	if err != nil {
		t.Fatal(err)
	}
	for _, file := range []string{"kitty/.config/kitty/kitty.conf", "ghostty/.config/ghostty/config", "wezterm/.config/wezterm/wezterm.lua"} {
		data, err := os.ReadFile(filepath.Join("..", "..", "config", file))
		if err != nil {
			t.Fatal(err)
		}
		for _, color := range append(theme.Palette[:], theme.Background, theme.Foreground, theme.Selection) {
			if !strings.Contains(string(data), color) {
				t.Fatalf("%s is missing default Monokai color %s", file, color)
			}
		}
	}
}

func TestThemePreservesUntrackedConfiguration(t *testing.T) {
	for _, conflict := range []string{"personal-config", "untracked-theme", "modified-wezterm", "symlink"} {
		t.Run(conflict, func(t *testing.T) {
			home := t.TempDir()
			t.Setenv("HOME", home)
			t.Setenv("XDG_STATE_HOME", filepath.Join(home, "state"))
			config := filepath.Join(home, ".config", "kitty", "kitty.conf")
			if conflict == "modified-wezterm" {
				config = filepath.Join(home, ".config", "wezterm", "wezterm.lua")
			}
			if err := writeAtomic(config, []byte("personal settings"), 0644); err != nil {
				t.Fatal(err)
			}
			record := installRecord{Scope: "user"}
			if conflict != "personal-config" {
				record.Paths = []string{config}
			}
			if conflict == "untracked-theme" {
				if err := writeAtomic(filepath.Join(filepath.Dir(config), "airgap-theme.conf"), []byte("personal colors"), 0644); err != nil {
					t.Fatal(err)
				}
			}
			if conflict == "symlink" {
				target := filepath.Join(home, "personal")
				if err := os.Rename(config, target); err != nil {
					t.Fatal(err)
				}
				if err := os.Symlink(target, config); err != nil {
					t.Fatal(err)
				}
			}
			if err := saveInstallRecord(record); err != nil {
				t.Fatal(err)
			}
			command := New("test", "test")
			command.SetArgs([]string{"theme", "set", "midnight"})
			if err := command.Execute(); err == nil {
				t.Fatal("unsafe configuration was accepted")
			}
			data, err := os.ReadFile(config)
			if err != nil || string(data) != "personal settings" {
				t.Fatalf("personal config changed: %s %v", data, err)
			}
		})
	}
}

func TestTerminalThemeColors(t *testing.T) {
	hex := regexp.MustCompile(`^#[0-9a-f]{6}$`)
	seen := map[string]bool{}
	for _, theme := range terminalThemes {
		if seen[theme.Name] || theme.Name == "" {
			t.Fatalf("duplicate or empty theme name: %q", theme.Name)
		}
		seen[theme.Name] = true
		for _, color := range append(theme.Palette[:], theme.Background, theme.Foreground, theme.Selection) {
			if !hex.MatchString(color) {
				t.Fatalf("invalid color in %s: %q", theme.Name, color)
			}
		}
		for _, terminal := range []string{"kitty", "ghostty", "wezterm"} {
			config, err := terminalThemeConfig(terminal, theme)
			if err != nil {
				t.Fatal(err)
			}
			for _, color := range append(theme.Palette[:], theme.Background, theme.Foreground, theme.Selection) {
				if !strings.Contains(config, color) {
					t.Fatalf("%s/%s is missing %s", terminal, theme.Name, color)
				}
			}
			for index := range theme.Palette {
				if terminal == "kitty" && !strings.Contains(config, fmt.Sprintf("color%d ", index)) {
					t.Fatalf("Kitty theme is missing ANSI color %d", index)
				}
				if terminal == "ghostty" && !strings.Contains(config, fmt.Sprintf("palette = %d=", index)) {
					t.Fatalf("Ghostty theme is missing ANSI color %d", index)
				}
			}
		}
	}
	if _, err := findTerminalTheme("../../other"); err == nil {
		t.Fatal("unknown theme accepted")
	}
	if _, err := terminalThemeConfig("unknown", terminalThemes[0]); err == nil {
		t.Fatal("unknown terminal accepted")
	}
}
