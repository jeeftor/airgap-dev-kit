package cli

import (
	"bytes"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"

	tea "charm.land/bubbletea/v2"
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

func TestManagedShellInitializesZoxideLast(t *testing.T) {
	path := filepath.Join(t.TempDir(), "shell.sh")
	if err := writeAirgapShellFile(path); err != nil {
		t.Fatalf("write managed shell file: %v", err)
	}
	content, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read managed shell file: %v", err)
	}
	starship := strings.Index(string(content), "starship init")
	zoxide := strings.Index(string(content), "zoxide init")
	if starship < 0 || zoxide < 0 || starship > zoxide {
		t.Fatalf("managed shell file must initialize Starship before zoxide:\n%s", content)
	}
}

func TestInstallPlannerSelectsRecoverableReplaceAndNoShellChanges(t *testing.T) {
	model := installModel{
		options:      installOptions{ConfigureShell: true, NvimMode: "preserve"},
		existingNvim: true,
	}

	model = updateInstallPlanner(t, model, "enter") // Full kit.
	model = updateInstallPlanner(t, model, "down")
	model = updateInstallPlanner(t, model, "enter") // Back up and replace.
	model = updateInstallPlanner(t, model, "down")
	model = updateInstallPlanner(t, model, "enter") // Do not change shell files.

	if model.step != 3 || model.options.NvimMode != "replace" || model.options.ConfigureShell {
		t.Fatalf("unexpected install plan: %#v", model)
	}
	view := model.View()
	if !strings.Contains(view.Content, "Back up and replace") || !strings.Contains(view.Content, "Do not change shell startup files") {
		t.Fatalf("review does not describe selected plan: %s", view.Content)
	}
}

func TestInstallPlannerPreservesExistingNeovimByDefault(t *testing.T) {
	model := installModel{
		options:      installOptions{ConfigureShell: true, NvimMode: "preserve"},
		existingNvim: true,
	}
	model = updateInstallPlanner(t, model, "enter")
	model = updateInstallPlanner(t, model, "enter")
	if model.options.NvimMode != "preserve" {
		t.Fatalf("default Neovim choice = %q, want preserve", model.options.NvimMode)
	}
}

func TestInstallPlannerSelectsDestructiveNeovimOverwrite(t *testing.T) {
	model := installModel{options: installOptions{ConfigureShell: true, NvimMode: "preserve"}, existingNvim: true}
	model = updateInstallPlanner(t, model, "enter")
	model = updateInstallPlanner(t, model, "down")
	model = updateInstallPlanner(t, model, "down")
	model = updateInstallPlanner(t, model, "enter")
	model = updateInstallPlanner(t, model, "enter")
	if model.options.NvimMode != "overwrite" {
		t.Fatalf("Neovim mode = %q, want overwrite", model.options.NvimMode)
	}
	view := model.View()
	if !strings.Contains(view.Content, "Delete and overwrite") || !strings.Contains(view.Content, "Permanent deletion") {
		t.Fatalf("review does not warn about destructive overwrite: %s", view.Content)
	}
}

func TestInstallNvimPayloadOverwriteDeletesExistingProfile(t *testing.T) {
	home := t.TempDir()
	dataHome := filepath.Join(home, ".local", "share")
	payload := filepath.Join(t.TempDir(), "payload")
	if err := os.MkdirAll(filepath.Join(payload, "nvim-runtime", "syntax"), 0755); err != nil {
		t.Fatal(err)
	}
	for path, content := range map[string]string{
		"nvim-static-x86_64":             "#!/bin/sh\n",
		"nvim-runtime/syntax/syntax.vim": "runtime\n",
	} {
		if err := os.WriteFile(filepath.Join(payload, path), []byte(content), 0755); err != nil {
			t.Fatal(err)
		}
	}
	for _, path := range nvimProfilePaths(home, dataHome) {
		if err := os.MkdirAll(path, 0755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(filepath.Join(path, "old"), []byte("old\n"), 0644); err != nil {
			t.Fatal(err)
		}
	}
	record := installRecord{}
	if err := installNvimPayload(t.TempDir(), payload, home, dataHome, "overwrite", &record); err != nil {
		t.Fatalf("overwrite Neovim profile: %v", err)
	}
	if _, err := os.Stat(filepath.Join(home, ".config", "nvim")); !os.IsNotExist(err) {
		t.Fatalf("old Neovim config still exists: %v", err)
	}
	for _, path := range []string{filepath.Join(dataHome, "nvim", "old"), filepath.Join(home, ".local", "state", "nvim", "old"), filepath.Join(home, ".cache", "nvim", "old")} {
		if _, err := os.Stat(path); !os.IsNotExist(err) {
			t.Fatalf("old Neovim state still exists at %s: %v", path, err)
		}
	}
	if _, err := os.Stat(filepath.Join(dataHome, "airgap-dev-kit", "backups")); !os.IsNotExist(err) {
		t.Fatalf("overwrite unexpectedly created a backup: %v", err)
	}
}

func TestInstallProgressRendersCompletedResults(t *testing.T) {
	model := newInstallProgressModel([]installStep{
		{label: "Copy command-line payload", result: "Installed", details: "Offline binaries copied", action: func() error { return nil }},
		{label: "Keep existing Neovim profile", result: "Preserved", details: "No files changed", action: func() error { return nil }},
	})
	updated, _ := model.Update(installStepDone{})
	model = updated.(installProgressModel)
	updated, _ = model.Update(installStepDone{})
	model = updated.(installProgressModel)
	view := model.View().Content
	for _, expected := range []string{"Installation complete", "Installed", "Preserved", "Copy command-line payload"} {
		if !strings.Contains(view, expected) {
			t.Fatalf("completed progress view is missing %q: %s", expected, view)
		}
	}
}

func TestInstallProgressRendersRecoveryPanel(t *testing.T) {
	model := newInstallProgressModel([]installStep{{label: "Copy command-line payload", action: func() error { return nil }}})
	updated, _ := model.Update(installStepDone{err: os.ErrPermission})
	model = updated.(installProgressModel)
	view := model.View().Content
	for _, expected := range []string{"Installation stopped", "Copy command-line payload", "airgap doctor"} {
		if !strings.Contains(view, expected) {
			t.Fatalf("failure progress view is missing %q: %s", expected, view)
		}
	}
}

func updateInstallPlanner(t *testing.T, model installModel, key string) installModel {
	t.Helper()
	keyType := tea.KeyEnter
	if key == "down" {
		keyType = tea.KeyDown
	}
	updated, _ := model.Update(tea.KeyPressMsg{Code: keyType})
	result, ok := updated.(installModel)
	if !ok {
		t.Fatalf("planner update returned %T", updated)
	}
	return result
}

func TestNativeInstallSetsBundledNeovimRuntime(t *testing.T) {
	t.Setenv("NO_COLOR", "1")
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("SHELL", "/bin/bash")
	t.Setenv("XDG_DATA_HOME", filepath.Join(home, ".local", "share"))
	t.Setenv("XDG_STATE_HOME", filepath.Join(home, ".local", "state"))
	if err := os.WriteFile(filepath.Join(home, ".bashrc"), []byte("# personal shell setup\n"), 0644); err != nil {
		t.Fatal(err)
	}
	kit := t.TempDir()
	payload := filepath.Join(kit, "offline-packages", "linux", "amd64")
	if err := os.MkdirAll(filepath.Join(payload, "nvim-runtime", "syntax"), 0755); err != nil {
		t.Fatal(err)
	}
	for path, content := range map[string]string{
		"kit-manifest.json": `{"schema_version":1,"version":"v2.0.2","target":"linux/amd64","payload_dir":"offline-packages/linux/amd64"}`,
		"offline-packages/linux/amd64/nvim-static-x86_64":             "#!/bin/sh\nprintf '%s' \"$VIMRUNTIME\"\n",
		"offline-packages/linux/amd64/nvim-runtime/syntax/syntax.vim": "runtime\n",
		"config/nvim/.config/nvim/init.lua":                           "-- kit config\n",
	} {
		if err := os.MkdirAll(filepath.Dir(filepath.Join(kit, path)), 0755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(filepath.Join(kit, path), []byte(content), 0755); err != nil {
			t.Fatal(err)
		}
	}
	t.Setenv("AIRGAP_KIT_DIR", kit)
	root := New("v2.0.2", "abc1234")
	root.SetArgs([]string{"install", "--yes", "--nvim-mode=replace"})
	if err := root.Execute(); err != nil {
		t.Fatal(err)
	}
	launcher := filepath.Join(home, ".local", "bin", "nvim")
	output, err := exec.Command(launcher).Output()
	if err != nil {
		t.Fatalf("run nvim launcher: %v", err)
	}
	wantRuntime := filepath.Join(home, ".local", "share", "nvim", "runtime")
	if got := string(output); got != wantRuntime {
		t.Fatalf("VIMRUNTIME = %q, want %q", got, wantRuntime)
	}
	if _, err := os.Stat(filepath.Join(home, ".config", "nvim", "init.lua")); err != nil {
		t.Fatalf("Neovim config was not installed: %v", err)
	}
	bashrc, err := os.ReadFile(filepath.Join(home, ".bashrc"))
	shellFile := filepath.Join(home, ".config", "airgap-dev-kit", "shell.sh")
	if err != nil || !strings.Contains(string(bashrc), shellBlockStart) || !strings.Contains(string(bashrc), shellFile) {
		t.Fatalf("Bash startup block was not installed: %v\n%s", err, bashrc)
	}
	if shellContent, err := os.ReadFile(shellFile); err != nil || !strings.Contains(string(shellContent), "zoxide init") {
		t.Fatalf("managed shell source was not installed: %v\n%s", err, shellContent)
	}
	root = New("v2.0.2", "abc1234")
	var statusOutput bytes.Buffer
	root.SetOut(&statusOutput)
	root.SetArgs([]string{"status"})
	if err := root.Execute(); err != nil {
		t.Fatal(err)
	}
	for _, expected := range []string{"Recorded components:", "binary — " + launcher, "not found on PATH", "file — " + shellFile} {
		if !strings.Contains(statusOutput.String(), expected) {
			t.Fatalf("status is missing %q: %s", expected, statusOutput.String())
		}
	}
	root = New("v2.0.2", "abc1234")
	var doctorOutput bytes.Buffer
	root.SetOut(&doctorOutput)
	root.SetArgs([]string{"doctor"})
	if err := root.Execute(); err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(doctorOutput.String(), "run nvim") {
		t.Fatalf("doctor did not run the installed Neovim binary: %s", doctorOutput.String())
	}
	userFile := filepath.Join(home, ".config", "nvim", "after-install.lua")
	if err := os.WriteFile(userFile, []byte("-- user file\n"), 0644); err != nil {
		t.Fatal(err)
	}
	root = New("v2.0.2", "abc1234")
	root.SetArgs([]string{"uninstall", "--yes"})
	if err := root.Execute(); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(userFile); err != nil {
		t.Fatalf("uninstall removed an untracked file: %v", err)
	}
	if _, err := os.Stat(filepath.Join(home, ".config", "nvim", "init.lua")); !os.IsNotExist(err) {
		t.Fatalf("uninstall did not remove tracked config: %v", err)
	}
	bashrc, err = os.ReadFile(filepath.Join(home, ".bashrc"))
	if err != nil || strings.Contains(string(bashrc), shellBlockStart) || !strings.Contains(string(bashrc), "# personal shell setup") {
		t.Fatalf("uninstall did not safely remove the Bash startup block: %v\n%s", err, bashrc)
	}
	if _, err := os.Stat(shellFile); !os.IsNotExist(err) {
		t.Fatalf("uninstall did not remove the managed shell source: %v", err)
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
	if err := os.WriteFile(filepath.Join(kit, "kit-manifest.json"), []byte(`{"schema_version":1,"version":"v2.0.0","target":"linux/amd64","payload_dir":"offline-packages/linux/amd64"}`), 0644); err != nil {
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

func TestInstallHelpDocumentsNativeOptions(t *testing.T) {
	t.Setenv("NO_COLOR", "1")
	root := New("v2.0.0-test", "abc1234")
	var output bytes.Buffer
	root.SetOut(&output)
	root.SetArgs([]string{"install", "--help"})
	if err := root.Execute(); err != nil {
		t.Fatal(err)
	}
	for _, expected := range []string{"--yes, -y", "--nvim-mode MODE", "--cli-only"} {
		if !strings.Contains(output.String(), expected) {
			t.Fatalf("install help does not document %q: %s", expected, output.String())
		}
	}
}
