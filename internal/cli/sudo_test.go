package cli

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestSystemInstallAuthenticatesBeforeWriting(t *testing.T) {
	if os.Geteuid() == 0 {
		t.Skip("sudo authentication is bypassed when already root")
	}
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("NO_COLOR", "1")
	kit := t.TempDir()
	payload := filepath.Join(kit, "offline-packages", "linux", "amd64")
	if err := os.MkdirAll(payload, 0755); err != nil {
		t.Fatal(err)
	}
	for name, content := range map[string]string{
		"airgap":            "#!/bin/sh\nexit 0\n",
		"kit-manifest.json": `{"schema_version":1,"version":"v0.0.0","target":"linux/amd64","payload_dir":"offline-packages/linux/amd64"}`,
	} {
		if err := os.WriteFile(filepath.Join(kit, name), []byte(content), 0755); err != nil {
			t.Fatal(err)
		}
	}
	t.Setenv("AIRGAP_KIT_DIR", kit)
	bin := t.TempDir()
	log := filepath.Join(t.TempDir(), "sudo.log")
	t.Setenv("SUDO_TEST_LOG", log)
	stub := "#!/bin/sh\nprintf '%s\\n' \"$*\" > \"$SUDO_TEST_LOG\"\nprintf 'Password: ' >&2\nread -r response\nprintf '%s\\n' \"$response\" >> \"$SUDO_TEST_LOG\"\nexit 1\n"
	if err := os.WriteFile(filepath.Join(bin, "sudo"), []byte(stub), 0755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", bin)
	root := New("v0.0.0", "test")
	var output, errors bytes.Buffer
	root.SetOut(&output)
	root.SetErr(&errors)
	root.SetIn(strings.NewReader("test response\n"))
	root.SetArgs([]string{"install", "--scope=system", "--yes", "--cli-only"})
	if err := root.Execute(); err == nil || !strings.Contains(err.Error(), "authenticate sudo") {
		t.Fatalf("expected authentication failure, got %v", err)
	}
	content, err := os.ReadFile(log)
	if err != nil || string(content) != "-v\ntest response\n" {
		t.Fatalf("authentication did not receive terminal input before privileged writes: %q, %v", content, err)
	}
	if !strings.Contains(errors.String(), "Password: ") || strings.Contains(output.String(), "Airgap install") {
		t.Fatalf("password prompt must be visible before the install interface: stdout=%q stderr=%q", output.String(), errors.String())
	}
	entries, err := os.ReadDir(home)
	if err != nil || len(entries) != 0 {
		t.Fatalf("failed authentication changed your home: %v, %v", entries, err)
	}
}

func TestPrivilegedStepsCannotPromptInsideUI(t *testing.T) {
	if os.Geteuid() == 0 {
		t.Skip("sudo is bypassed when already root")
	}
	bin := t.TempDir()
	stub := "#!/bin/sh\nif [ \"$1\" != -n ]; then echo 'interactive sudo inside UI' >&2; exit 1; fi\nshift\n[ \"$*\" = 'mkdir -p /example' ]\n"
	if err := os.WriteFile(filepath.Join(bin, "sudo"), []byte(stub), 0755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", bin)
	if err := runSudo("mkdir", "-p", "/example"); err != nil {
		t.Fatal(err)
	}
}
