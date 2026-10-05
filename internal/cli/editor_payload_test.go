package cli

import (
	"archive/tar"
	"compress/gzip"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func TestEditorPayloadInstallsExecutableCLIParsersAndLock(t *testing.T) {
	for _, withSite := range []bool{false, true} {
		t.Run(map[bool]string{false: "older-plugin-only", true: "parsers-and-cli"}[withSite], func(t *testing.T) {
			root := t.TempDir()
			archive := filepath.Join(root, "lazy.tar.gz")
			file, err := os.Create(archive)
			if err != nil {
				t.Fatal(err)
			}
			gz := gzip.NewWriter(file)
			tw := tar.NewWriter(gz)
			files := map[string]string{"lazy/example/init.lua": "return {}", "lazy-lock.json": "{}"}
			if withSite {
				files["site/parser/lua.so"] = "parser payload"
				files["site/bin/tree-sitter"] = "#!/bin/sh\necho bundled-cli\n"
			}
			for name, data := range files {
				mode := int64(0644)
				if name == "site/bin/tree-sitter" {
					mode = 0755
				}
				if err := tw.WriteHeader(&tar.Header{Name: name, Mode: mode, Size: int64(len(data))}); err != nil {
					t.Fatal(err)
				}
				if _, err := tw.Write([]byte(data)); err != nil {
					t.Fatal(err)
				}
			}
			for _, close := range []func() error{tw.Close, gz.Close, file.Close} {
				if err := close(); err != nil {
					t.Fatal(err)
				}
			}
			dataDir := filepath.Join(root, "nvim")
			var record installRecord
			if err := installEditorPayload(archive, []string{"lazy", "site"}, dataDir, &record); err != nil {
				t.Fatal(err)
			}
			lock, err := os.ReadFile(filepath.Join(dataDir, "lazy-lock.json"))
			if err != nil || string(lock) != "{}" {
				t.Fatalf("lock = %q %v", lock, err)
			}
			if withSite {
				output, err := exec.Command(filepath.Join(dataDir, "site", "bin", "tree-sitter")).Output()
				if err != nil || string(output) != "bundled-cli\n" {
					t.Fatalf("CLI = %q %v", output, err)
				}
				if _, err := os.Stat(filepath.Join(dataDir, "site", "parser", "lua.so")); err != nil {
					t.Fatal(err)
				}
			}
			for _, path := range record.Paths {
				if err := os.RemoveAll(path); err != nil {
					t.Fatal(err)
				}
			}
			if _, err := os.Stat(filepath.Join(dataDir, "site")); !os.IsNotExist(err) {
				t.Fatalf("untracked parser payload remains: %v", err)
			}
		})
	}
}

func TestLazyVimChoiceIncludesRuntimeTools(t *testing.T) {
	for _, mode := range []string{"fresh", "replace", "preserve"} {
		t.Run(mode, func(t *testing.T) {
			payload, bin := t.TempDir(), t.TempDir()
			for _, name := range []string{"fd", "fzf", "rg", "lazygit", "bat"} {
				if err := os.WriteFile(filepath.Join(payload, name), []byte("#!/bin/sh\nexit 0\n"), 0755); err != nil {
					t.Fatal(err)
				}
			}
			model := installModel{step: 3, existingNvim: mode != "fresh", options: installOptions{NvimMode: "preserve", Tools: map[string]bool{}}}
			if mode == "replace" {
				model.choice = 1
			}
			model = updateInstallPlanner(t, model, "enter")
			var record installRecord
			if err := copyPayloadBinaries(payload, bin, t.TempDir(), "user", true, model.options.Tools, &record); err != nil {
				t.Fatal(err)
			}
			for _, name := range []string{"fd", "fzf", "rg", "lazygit"} {
				_, err := os.Stat(filepath.Join(bin, name))
				if mode == "preserve" {
					if !os.IsNotExist(err) {
						t.Fatalf("preserving profile installed deselected %s: %v", name, err)
					}
				} else if err != nil {
					t.Fatalf("LazyVim choice omitted required %s: %v", name, err)
				}
			}
			if _, err := os.Stat(filepath.Join(bin, "bat")); !os.IsNotExist(err) {
				t.Fatalf("unrelated deselected tool installed: %v", err)
			}
		})
	}
}

func TestLazyVimMissingToolFailsBeforeChangingHome(t *testing.T) {
	home, kit := t.TempDir(), t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_DATA_HOME", filepath.Join(home, ".local", "share"))
	t.Setenv("AIRGAP_KIT_DIR", kit)
	payload := filepath.Join(kit, "offline-packages", "linux", "amd64")
	if err := os.MkdirAll(payload, 0755); err != nil {
		t.Fatal(err)
	}
	for name, data := range map[string]string{
		"airgap":            "#!/bin/sh\nexit 0\n",
		"kit-manifest.json": `{"schema_version":1,"version":"v0.0.0","target":"linux/amd64","payload_dir":"offline-packages/linux/amd64"}`,
	} {
		if err := os.WriteFile(filepath.Join(kit, name), []byte(data), 0755); err != nil {
			t.Fatal(err)
		}
	}
	root := New("v0.0.0", "test")
	root.SetArgs([]string{"install", "--yes", "--cli-only", "--nvim-mode=replace"})
	if err := root.Execute(); err == nil || !strings.Contains(err.Error(), "LazyVim requires bundled executable fd") {
		t.Fatalf("incomplete kit was not rejected: %v", err)
	}
	entries, err := os.ReadDir(home)
	if err != nil || len(entries) != 0 {
		t.Fatalf("incomplete kit modified your home: %v %v", entries, err)
	}
}

func TestWezTermConfigInstallPreservesPersonalFile(t *testing.T) {
	root, home := t.TempDir(), t.TempDir()
	source := filepath.Join(root, "config", "wezterm", ".config", "wezterm", "wezterm.lua")
	destination := filepath.Join(home, ".config", "wezterm", "wezterm.lua")
	for _, path := range []string{source, destination} {
		if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil {
			t.Fatal(err)
		}
	}
	if err := os.WriteFile(source, []byte("kit preset"), 0644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(destination, []byte("personal config"), 0644); err != nil {
		t.Fatal(err)
	}
	var record installRecord
	if err := copyManagedConfig(root, home, false, &record); err != nil {
		t.Fatal(err)
	}
	data, err := os.ReadFile(destination)
	if err != nil || string(data) != "personal config" || len(record.Paths) != 0 {
		t.Fatalf("personal config overwritten or tracked for removal: %q %v %#v", data, err, record.Paths)
	}
}
