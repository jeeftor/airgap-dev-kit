package cli

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestAddBinaryRunCheckIncludesFailureOutputAndRemediation(t *testing.T) {
	path := writeProbeScript(t, "tmux", `
echo "runtime library is missing" >&2
exit 7
`)
	var report doctorReport
	addBinaryRunCheck(&report, path)

	if len(report.Checks) != 1 {
		t.Fatalf("checks = %d, want 1", len(report.Checks))
	}
	check := report.Checks[0]
	if check.Status != "fail" {
		t.Fatalf("status = %q, want fail", check.Status)
	}
	for _, want := range []string{"exit status 7", "runtime library is missing", "Remediation: run " + path + " -V directly"} {
		if !strings.Contains(check.Detail, want) {
			t.Errorf("detail is missing %q: %s", want, check.Detail)
		}
	}
}

func TestAddBinaryRunCheckExplainsWezTermFUSEFallback(t *testing.T) {
	path := writeProbeScript(t, "wezterm", `
if [ "$1" = "--appimage-extract-and-run" ]; then
  exit 0
fi
echo "fuse: failed to execute fusermount: No such file or directory" >&2
exit 1
`)
	var report doctorReport
	addBinaryRunCheck(&report, path)

	if len(report.Checks) != 1 {
		t.Fatalf("checks = %d, want 1", len(report.Checks))
	}
	check := report.Checks[0]
	if check.Status != "warn" {
		t.Fatalf("status = %q, want warn", check.Status)
	}
	for _, want := range []string{"needs FUSE", "fusermount", "--appimage-extract-and-run --version completed", "Remediation: install an AppImage-compatible FUSE runtime"} {
		if !strings.Contains(check.Detail, want) {
			t.Errorf("detail is missing %q: %s", want, check.Detail)
		}
	}
}

func TestProbeFailureDetailCompactsAndBoundsOutput(t *testing.T) {
	result := versionProbeResult{
		Err:             os.ErrNotExist,
		Output:          "first line\nsecond\tline " + strings.Repeat("x", versionProbeDetailLimit),
		OutputTruncated: true,
	}
	detail := probeFailureDetail(result)
	if strings.Contains(detail, "\n") || strings.Contains(detail, "\t") {
		t.Fatalf("detail contains whitespace control characters: %q", detail)
	}
	for _, want := range []string{"file does not exist", "first line second line", "...", "(output truncated)"} {
		if !strings.Contains(detail, want) {
			t.Errorf("detail is missing %q: %s", want, detail)
		}
	}
}

func TestDoctorOnlyProbesCommandsInstalledInLocalBin(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	binDir := filepath.Join(home, ".local", "bin")
	if err := os.MkdirAll(binDir, 0755); err != nil {
		t.Fatal(err)
	}
	bat := writeProbeScript(t, "bat", "exit 0")
	if err := os.Rename(bat, filepath.Join(binDir, "bat")); err != nil {
		t.Fatal(err)
	}
	config := filepath.Join(home, ".config", "nvim", "LICENSE")
	if err := os.MkdirAll(filepath.Dir(config), 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(config, []byte("license"), 0755); err != nil {
		t.Fatal(err)
	}
	payload := t.TempDir()
	if err := os.WriteFile(filepath.Join(payload, "bat"), []byte("#!/bin/sh\nexit 0\n"), 0755); err != nil {
		t.Fatal(err)
	}
	record := installRecord{Paths: []string{filepath.Join(binDir, "bat"), config}}
	if err := saveInstallRecord(record); err != nil {
		t.Fatal(err)
	}
	var report doctorReport
	addInstalledBinaryChecks(&report, payload)
	if len(report.Checks) != 2 || report.Checks[0].Name != "installed binary bat" || report.Checks[1].Name != "run bat" {
		t.Fatalf("doctor checks = %#v, want only bat", report.Checks)
	}
}

func writeProbeScript(t *testing.T, name, body string) string {
	t.Helper()
	path := filepath.Join(t.TempDir(), name)
	if err := os.WriteFile(path, []byte("#!/bin/sh\n"+body), 0755); err != nil {
		t.Fatalf("write probe script: %v", err)
	}
	return path
}
