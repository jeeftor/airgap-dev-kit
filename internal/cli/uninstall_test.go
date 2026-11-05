package cli

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestUninstallWithoutRecord(t *testing.T) {
	t.Setenv("XDG_STATE_HOME", t.TempDir())
	root := New("test", "test")
	var output bytes.Buffer
	root.SetOut(&output)
	root.SetArgs([]string{"uninstall"})
	if err := root.Execute(); err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(output.String(), "No native airgap installation record found.") {
		t.Fatalf("unexpected output: %s", output.String())
	}
}

func TestUninstallConfirmation(t *testing.T) {
	for _, test := range []struct {
		name  string
		input string
		want  bool
	}{
		{"yes", "yes\n", true},
		{"short yes", "y\n", true},
		{"case and whitespace", " YES \n", true},
		{"default no", "\n", false},
		{"no", "n\n", false},
		{"invalid", "anything\n", false},
		{"end of input", "", false},
		{"incomplete answer", "yes", false},
	} {
		t.Run(test.name, func(t *testing.T) {
			command := New("test", "test")
			command.SetIn(strings.NewReader(test.input))
			var output bytes.Buffer
			command.SetOut(&output)
			got, err := confirmUninstall(command)
			if err != nil || got != test.want {
				t.Fatalf("confirmation = %v, %v; want %v", got, err, test.want)
			}
			if !strings.Contains(output.String(), "[y/N]") {
				t.Fatalf("missing default-no prompt: %s", output.String())
			}
		})
	}
}

func TestUninstallNoninteractive(t *testing.T) {
	for _, mode := range []string{"unconfirmed", "dry-run", "yes"} {
		t.Run(mode, func(t *testing.T) {
			t.Setenv("XDG_STATE_HOME", t.TempDir())
			tracked := filepath.Join(t.TempDir(), "tracked")
			if err := os.WriteFile(tracked, []byte("installed"), 0600); err != nil {
				t.Fatal(err)
			}
			if err := saveInstallRecord(installRecord{Scope: "user", Paths: []string{tracked}}); err != nil {
				t.Fatal(err)
			}
			root := New("test", "test")
			var output bytes.Buffer
			root.SetOut(&output)
			root.SetErr(&output)
			root.SetIn(strings.NewReader("yes\n"))
			args := []string{"uninstall"}
			if mode != "unconfirmed" {
				args = append(args, "--"+mode)
			}
			root.SetArgs(args)
			err := root.Execute()
			if mode == "unconfirmed" {
				if err == nil || !strings.Contains(err.Error(), "--yes") {
					t.Fatalf("expected confirmation error, got %v", err)
				}
			} else if err != nil {
				t.Fatal(err)
			}
			_, statErr := os.Stat(tracked)
			if mode == "yes" {
				if !os.IsNotExist(statErr) {
					t.Fatalf("confirmed uninstall did not remove tracked file: %v", statErr)
				}
			} else if statErr != nil {
				t.Fatalf("unconfirmed uninstall changed tracked file: %v", statErr)
			}
			if mode == "dry-run" && !strings.Contains(output.String(), "would remove "+tracked) {
				t.Fatalf("missing removal preview: %s", output.String())
			}
		})
	}
}
