package cli

import (
	"archive/tar"
	"compress/gzip"
	"os"
	"os/exec"
	"path/filepath"
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
