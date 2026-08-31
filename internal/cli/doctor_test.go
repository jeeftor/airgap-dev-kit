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

func writeProbeScript(t *testing.T, name, body string) string {
	t.Helper()
	path := filepath.Join(t.TempDir(), name)
	if err := os.WriteFile(path, []byte("#!/bin/sh\n"+body), 0755); err != nil {
		t.Fatalf("write probe script: %v", err)
	}
	return path
}
