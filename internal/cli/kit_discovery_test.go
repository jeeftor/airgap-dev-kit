package cli

import (
	"os"
	"path/filepath"
	"testing"
)

func TestInstalledKitDiscoveryWithoutEnvironmentOverride(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_STATE_HOME", filepath.Join(home, ".local", "state"))
	t.Setenv("XDG_DATA_HOME", filepath.Join(home, ".local", "share"))
	t.Setenv("AIRGAP_KIT_DIR", "")
	t.Chdir(t.TempDir())
	kit := t.TempDir()
	if err := os.MkdirAll(filepath.Join(kit, "offline-packages", "linux"), 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(kit, "kit-manifest.json"), []byte(`{"schema_version":1}`), 0644); err != nil {
		t.Fatal(err)
	}
	if err := saveInstallRecord(installRecord{Version: "v0.0.0", KitDir: kit}); err != nil {
		t.Fatal(err)
	}
	root, found := discoveredKitRoot()
	if !found || root != kit {
		t.Fatalf("installed kit was not discovered from its record: (%q, %t)", root, found)
	}
	if err := os.RemoveAll(kit); err != nil {
		t.Fatal(err)
	}
	if root, found := discoveredKitRoot(); found {
		t.Fatalf("missing recorded kit must not be treated as available: %q", root)
	}
}
