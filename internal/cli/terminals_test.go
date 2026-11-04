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

func TestPortableTerminalsInstallSelectAndRemove(t *testing.T) {
	root := filepath.Join(t.TempDir(), "Your kit's home")
	payload, bin, data := filepath.Join(root, "payload"), filepath.Join(root, "bin"), filepath.Join(root, "data")
	if err := os.MkdirAll(payload, 0755); err != nil {
		t.Fatal(err)
	}
	archive := filepath.Join(payload, "kitty.tar.gz")
	file, err := os.Create(archive)
	if err != nil {
		t.Fatal(err)
	}
	gz := gzip.NewWriter(file)
	tw := tar.NewWriter(gz)
	script := "#!/bin/sh\ncat \"$(dirname \"$0\")/../lib/resource-link\"\n"
	for name, body := range map[string]string{"bin/kitty": script, "lib/resource": "portable-resource\n"} {
		mode := int64(0644)
		if name == "bin/kitty" {
			mode = 0755
		}
		if err := tw.WriteHeader(&tar.Header{Name: name, Mode: mode, Size: int64(len(body))}); err != nil {
			t.Fatal(err)
		}
		if _, err := tw.Write([]byte(body)); err != nil {
			t.Fatal(err)
		}
	}
	if err := tw.WriteHeader(&tar.Header{Name: "lib/resource-link", Typeflag: tar.TypeSymlink, Linkname: "resource"}); err != nil {
		t.Fatal(err)
	}
	for _, close := range []func() error{tw.Close, gz.Close, file.Close} {
		if err := close(); err != nil {
			t.Fatal(err)
		}
	}
	image := []byte("#!/bin/sh\nprintf '%s\n' \"$1\"\n")
	if err := os.WriteFile(filepath.Join(payload, "ghostty.AppImage"), image, 0644); err != nil {
		t.Fatal(err)
	}
	choices := availableCLIChoices(payload)
	if len(choices) != 2 || choices[0].Name != "ghostty" || choices[1].Name != "kitty" {
		t.Fatalf("choices: %#v", choices)
	}
	var record installRecord
	if err := copyPayloadBinaries(payload, bin, data, "user", true, nil, &record); err != nil {
		t.Fatal(err)
	}
	if len(record.Paths) != 0 {
		t.Fatal("CLI-only installed GUI payload")
	}
	if err := copyPayloadBinaries(payload, bin, data, "user", false, map[string]bool{"kitty": true}, &record); err != nil {
		t.Fatal(err)
	}
	output, err := exec.Command(filepath.Join(bin, "kitty")).CombinedOutput()
	if err != nil || string(output) != "portable-resource\n" {
		t.Fatalf("portable launcher/resources: %q %v", output, err)
	}
	if _, err := os.Stat(filepath.Join(bin, "ghostty")); !os.IsNotExist(err) {
		t.Fatal("deselected Ghostty installed")
	}
	if err := copyPayloadBinaries(payload, bin, data, "user", false, map[string]bool{"ghostty": true}, &record); err != nil {
		t.Fatal(err)
	}
	output, err = exec.Command(filepath.Join(bin, "ghostty"), "--version").CombinedOutput()
	if err != nil || !strings.Contains(string(output), "--appimage-extract-and-run") {
		t.Fatalf("Ghostty FUSE-free wrapper: %q %v", output, err)
	}
	for _, terminal := range []string{"kitty", "ghostty"} {
		menu := filepath.Join(root, terminal+".desktop")
		if err := installTerminalDesktop(bin, menu, "", "user", terminal, &record); err != nil {
			t.Fatal(err)
		}
		raw, err := os.ReadFile(menu)
		if err != nil {
			t.Fatal(err)
		}
		if !strings.Contains(string(raw), "/"+terminal+"\"") {
			t.Fatalf("bad launcher: %s", raw)
		}
		if terminal == "ghostty" && !strings.Contains(string(raw), "Experimental") {
			t.Fatal("missing experimental label")
		}
	}
	for _, path := range record.Paths {
		if err := removeInstalledPath(path, "user"); err != nil {
			t.Fatal(err)
		}
	}
	if _, err := os.Stat(filepath.Join(data, "kitty")); !os.IsNotExist(err) {
		t.Fatal("Kitty resources remain after removal")
	}
}

func TestRealKittyBundle(t *testing.T) {
	archive := os.Getenv("AIRGAP_TEST_KITTY_ARCHIVE")
	if archive == "" {
		t.Skip("set AIRGAP_TEST_KITTY_ARCHIVE on Linux to check the real upstream bundle")
	}
	root := t.TempDir()
	var record installRecord
	if err := installKittyBundle(archive, filepath.Join(root, "bin"), filepath.Join(root, "data"), "user", &record); err != nil {
		t.Fatal(err)
	}
	output, err := exec.Command(filepath.Join(root, "bin", "kitty"), "--version").CombinedOutput()
	if err != nil || !strings.Contains(string(output), "kitty ") {
		t.Fatalf("real Kitty bundle: %q %v", output, err)
	}
}
