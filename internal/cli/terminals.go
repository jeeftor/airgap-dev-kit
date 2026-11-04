package cli

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// installKittyBundle preserves the portable distribution's executable modes and
// internal symlinks. Copying only its launcher leaves a broken installation.
func installKittyBundle(archive, binDir, appDataDir, scope string, record *installRecord) error {
	stage, err := os.MkdirTemp("", "airgap-kitty-")
	if err != nil {
		return err
	}
	defer os.RemoveAll(stage)
	if err := extractSafeTarGz(archive, stage); err != nil {
		return fmt.Errorf("extract Kitty bundle: %w", err)
	}
	executable := filepath.Join(stage, "bin", "kitty")
	if info, err := os.Stat(executable); err != nil || !info.Mode().IsRegular() || info.Mode()&0111 == 0 {
		return fmt.Errorf("Kitty bundle has no executable bin/kitty")
	}
	destination := filepath.Join(appDataDir, "kitty")
	if err := makeInstallDir(appDataDir, scope); err != nil {
		return err
	}
	if err := removeInstalledPath(destination, scope); err != nil {
		return err
	}
	if scope == "system" {
		if err := runSudo("cp", "-a", stage, destination); err != nil {
			return err
		}
		if err := runSudo("chmod", "0755", destination); err != nil {
			return err
		}
	} else {
		// The temporary directory may be on a different filesystem.
		if err := os.MkdirAll(destination, 0755); err != nil {
			return err
		}
		if err := copyPortableTree(stage, destination); err != nil {
			return err
		}
	}
	record.Paths = append(record.Paths, destination)
	launcher := filepath.Join(binDir, "kitty")
	command := "'" + strings.ReplaceAll(filepath.Join(destination, "bin", "kitty"), "'", "'\"'\"'") + "'"
	if err := writeFileForScope(launcher, []byte("#!/bin/sh\nexec "+command+" \"$@\"\n"), 0755, scope); err != nil {
		return err
	}
	record.Paths = append(record.Paths, launcher)
	return nil
}

func copyPortableTree(source, destination string) error {
	entries, err := os.ReadDir(source)
	if err != nil {
		return err
	}
	for _, entry := range entries {
		from, to := filepath.Join(source, entry.Name()), filepath.Join(destination, entry.Name())
		info, err := entry.Info()
		if err != nil {
			return err
		}
		switch {
		case entry.Type()&os.ModeSymlink != 0:
			target, err := os.Readlink(from)
			if err != nil {
				return err
			}
			if err := os.Symlink(target, to); err != nil {
				return err
			}
		case entry.IsDir():
			if err := os.MkdirAll(to, 0755); err != nil {
				return err
			}
			if err := copyPortableTree(from, to); err != nil {
				return err
			}
		default:
			if err := copyFile(from, to, info.Mode().Perm()); err != nil {
				return err
			}
		}
	}
	return nil
}
