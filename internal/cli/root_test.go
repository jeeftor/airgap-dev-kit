package cli

import (
	"bytes"
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
