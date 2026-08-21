package cli

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestRootHelpIsUsefulWithoutColor(t *testing.T) {
	t.Setenv("NO_COLOR", "1")
	root := New("v2.0.0-test", "abc1234")
	var output bytes.Buffer
	root.SetOut(&output)
	root.SetArgs([]string{"--help"})
	if err := root.Execute(); err != nil {
		t.Fatal(err)
	}
	for _, expected := range []string{"Air-Gap Development Kit", "install", "doctor", "update"} {
		if !strings.Contains(output.String(), expected) {
			t.Fatalf("help is missing %q: %s", expected, output.String())
		}
	}
}

func TestStatusReportsWhenNoKitIsAvailable(t *testing.T) {
	t.Setenv("NO_COLOR", "1")
	t.Setenv("AIRGAP_KIT_DIR", t.TempDir())
	t.Chdir(t.TempDir())
	root := New("v2.0.0-test", "abc1234")
	var output bytes.Buffer
	root.SetOut(&output)
	root.SetArgs([]string{"status"})
	if err := root.Execute(); err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(output.String(), "Kit directory: not found") {
		t.Fatalf("status did not report the missing kit: %s", output.String())
	}
}

func TestDoctorReportsIncompleteKit(t *testing.T) {
	t.Setenv("NO_COLOR", "1")
	kit := t.TempDir()
	if err := os.WriteFile(filepath.Join(kit, "install.sh"), []byte("#!/bin/sh\n"), 0755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("AIRGAP_KIT_DIR", kit)
	root := New("v2.0.0-test", "abc1234")
	var output bytes.Buffer
	root.SetOut(&output)
	root.SetArgs([]string{"doctor"})
	if err := root.Execute(); err != nil {
		t.Fatal(err)
	}
	for _, expected := range []string{"Airgap doctor", "[⚠ WARN] kit version", "[✗ FAIL] payload directory", "Overall: ✗ NEEDS ATTENTION"} {
		if !strings.Contains(output.String(), expected) {
			t.Fatalf("doctor is missing %q: %s", expected, output.String())
		}
	}
}

func TestDoctorReportsHealthyV2Kit(t *testing.T) {
	t.Setenv("NO_COLOR", "1")
	kit := t.TempDir()
	payload := filepath.Join(kit, "offline-packages", "linux", "amd64")
	if err := os.MkdirAll(payload, 0755); err != nil {
		t.Fatal(err)
	}
	for path, content := range map[string]string{
		"install.sh":                          "#!/bin/sh\n",
		"VERSION":                             "v2.0.2\n",
		"kit-manifest.json":                   `{"schema_version":1,"version":"v2.0.2","target":"linux/amd64","payload_dir":"offline-packages/linux/amd64"}`,
		"offline-packages/linux/amd64/airgap": "#!/bin/sh\n",
	} {
		if err := os.WriteFile(filepath.Join(kit, path), []byte(content), 0755); err != nil {
			t.Fatal(err)
		}
	}
	if err := os.Symlink("offline-packages/linux/amd64/airgap", filepath.Join(kit, "airgap")); err != nil {
		t.Fatal(err)
	}
	t.Setenv("AIRGAP_KIT_DIR", kit)
	root := New("v2.0.2", "abc1234")
	var output bytes.Buffer
	root.SetOut(&output)
	root.SetArgs([]string{"doctor", "--verify"})
	if err := root.Execute(); err != nil {
		t.Fatal(err)
	}
	for _, expected := range []string{"Layout: v2 linux/amd64", "[✓ PASS] lifecycle binary", "[✓ PASS] root launcher", "Overall: ✓ HEALTHY"} {
		if !strings.Contains(output.String(), expected) {
			t.Fatalf("doctor is missing %q: %s", expected, output.String())
		}
	}
}

func TestTextOutputRemainsPlainWhenColorIsDisabled(t *testing.T) {
	t.Setenv("NO_COLOR", "1")
	root := New("v2.0.0-test", "abc1234")
	var output bytes.Buffer
	root.SetOut(&output)
	root.SetArgs([]string{"version"})
	if err := root.Execute(); err != nil {
		t.Fatal(err)
	}
	if got, want := output.String(), "airgap v2.0.0-test (abc1234)\n"; got != want {
		t.Fatalf("version output = %q, want %q", got, want)
	}
}

func TestNoTUIIsIgnoredByLegacyInstaller(t *testing.T) {
	args := withoutTUIFlag([]string{"--no-tui", "--dry-run"})
	if got, want := strings.Join(args, " "), "--dry-run"; got != want {
		t.Fatalf("installer arguments = %q, want %q", got, want)
	}
}

func TestInstallHelpDocumentsTUIOptOut(t *testing.T) {
	t.Setenv("NO_COLOR", "1")
	root := New("v2.0.0-test", "abc1234")
	var output bytes.Buffer
	root.SetOut(&output)
	root.SetArgs([]string{"install", "--help"})
	if err := root.Execute(); err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(output.String(), "--no-tui") {
		t.Fatalf("install help does not document --no-tui: %s", output.String())
	}
}
