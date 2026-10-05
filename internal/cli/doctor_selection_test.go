package cli

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestDoctorRespectsRecordedCommandSelections(t *testing.T) {
	for _, omitted := range []string{"wezterm.AppImage", "bat", "nvim-static-x86_64"} {
		t.Run(omitted, func(t *testing.T) {
			home, payload := t.TempDir(), t.TempDir()
			t.Setenv("HOME", home)
			t.Setenv("XDG_STATE_HOME", filepath.Join(home, ".local", "state"))
			bin := filepath.Join(home, ".local", "bin")
			t.Setenv("PATH", bin)
			if err := os.MkdirAll(bin, 0755); err != nil {
				t.Fatal(err)
			}
			installed := filepath.Join(bin, "rg")
			for _, path := range []string{installed, filepath.Join(payload, "rg"), filepath.Join(payload, omitted)} {
				if err := os.WriteFile(path, []byte("#!/bin/sh\nexit 0\n"), 0755); err != nil {
					t.Fatal(err)
				}
			}
			if err := saveInstallRecord(installRecord{Scope: "user", Paths: []string{installed}}); err != nil {
				t.Fatal(err)
			}
			var report doctorReport
			addInstalledBinaryChecks(&report, payload)
			if report.Failures != 0 || len(report.Checks) != 2 || report.Checks[0].Name != "installed binary rg" {
				t.Fatalf("deselected command failed doctor: %#v", report)
			}
			if err := os.Chmod(installed, 0644); err != nil {
				t.Fatal(err)
			}
			report = doctorReport{}
			addInstalledBinaryChecks(&report, payload)
			if report.Failures != 1 || !strings.Contains(report.Checks[0].Detail, "is not executable") {
				t.Fatalf("nonexecutable recorded command was not detected: %#v", report)
			}
			if err := os.Remove(installed); err != nil {
				t.Fatal(err)
			}
			report = doctorReport{}
			addInstalledBinaryChecks(&report, payload)
			if report.Failures != 1 || !strings.Contains(report.Checks[0].Detail, installed+" is missing") {
				t.Fatalf("missing recorded command was not detected: %#v", report)
			}
		})
	}
}

func TestDoctorChecksHelperPresenceWithoutRequiringShellActivation(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_STATE_HOME", filepath.Join(home, ".local", "state"))
	t.Setenv("PATH", "")
	bin := filepath.Join(home, ".local", "bin")
	if err := os.MkdirAll(bin, 0755); err != nil {
		t.Fatal(err)
	}
	helper := filepath.Join(bin, "vim-empty")
	if err := os.WriteFile(helper, []byte("#!/bin/sh\nexec nvim -u NONE -i NONE \"$@\"\n"), 0755); err != nil {
		t.Fatal(err)
	}
	if err := saveInstallRecord(installRecord{Scope: "user", Paths: []string{helper}}); err != nil {
		t.Fatal(err)
	}
	var report doctorReport
	addInstalledBinaryChecks(&report, t.TempDir())
	if report.Failures != 0 || report.Warnings != 1 || len(report.Checks) != 1 {
		t.Fatalf("helper failed before shell activation: %#v", report)
	}
}

func TestDoctorDetectsMissingRecordedSystemCommand(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_STATE_HOME", filepath.Join(home, ".local", "state"))
	missing := filepath.Join("/usr/local/bin", "airgap-doctor-missing-system-command")
	if _, err := os.Stat(missing); !os.IsNotExist(err) {
		t.Fatalf("system fixture unexpectedly exists: %v", err)
	}
	if err := saveInstallRecord(installRecord{Scope: "system", Paths: []string{missing}}); err != nil {
		t.Fatal(err)
	}
	var report doctorReport
	addInstalledBinaryChecks(&report, t.TempDir())
	if report.Failures != 1 || !strings.Contains(report.Checks[0].Detail, missing+" is missing") {
		t.Fatalf("missing recorded system command was not detected: %#v", report)
	}
}
