// Package release validates the signed, target-specific release metadata.
package release

import (
	"crypto/ed25519"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"regexp"
)

const SchemaVersion = 1

var semver = regexp.MustCompile(`^v?(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$`)

// Manifest describes every installable payload in one release.
type Manifest struct {
	SchemaVersion  int     `json:"schema_version"`
	Repository     string  `json:"repository"`
	Version        string  `json:"version"`
	Channel        string  `json:"channel"`
	MinimumUpdater string  `json:"minimum_updater_version"`
	Artifacts      []Asset `json:"artifacts"`
}

// Asset is an immutable target/flavor archive entry.
type Asset struct {
	Target string `json:"target"`
	Flavor string `json:"flavor"`
	Name   string `json:"name"`
	Size   int64  `json:"size"`
	SHA256 string `json:"sha256"`
}

// Parse validates public metadata before it is trusted for selection.
func Parse(raw []byte) (Manifest, error) {
	var m Manifest
	if err := json.Unmarshal(raw, &m); err != nil {
		return Manifest{}, fmt.Errorf("decode release manifest: %w", err)
	}
	if m.SchemaVersion != SchemaVersion || m.Repository == "" || !semver.MatchString(m.Version) {
		return Manifest{}, fmt.Errorf("invalid release manifest identity")
	}
	if m.Channel != "stable" && m.Channel != "prerelease" {
		return Manifest{}, fmt.Errorf("invalid release channel %q", m.Channel)
	}
	for _, a := range m.Artifacts {
		if a.Target == "" || (a.Flavor != "full" && a.Flavor != "cli") || filepath.Base(a.Name) != a.Name || a.Name == "." || a.Size < 1 || len(a.SHA256) != 64 {
			return Manifest{}, fmt.Errorf("invalid artifact entry")
		}
		if _, err := hex.DecodeString(a.SHA256); err != nil {
			return Manifest{}, fmt.Errorf("invalid artifact digest: %w", err)
		}
	}
	return m, nil
}

// VerifySignature checks raw manifest bytes against any embedded trusted key.
func VerifySignature(raw, signature []byte, encodedKeys []string) error {
	if decoded, err := base64.StdEncoding.DecodeString(string(signature)); err == nil {
		signature = decoded
	}
	if len(signature) != ed25519.SignatureSize {
		return fmt.Errorf("invalid manifest signature size")
	}
	for _, encoded := range encodedKeys {
		key, err := base64.StdEncoding.DecodeString(encoded)
		if err != nil || len(key) != ed25519.PublicKeySize {
			continue
		}
		if ed25519.Verify(ed25519.PublicKey(key), raw, signature) {
			return nil
		}
	}
	return fmt.Errorf("release manifest signature is not trusted")
}

// Select returns the single archive for a target and flavor.
func (m Manifest) Select(target, flavor string) (Asset, error) {
	for _, a := range m.Artifacts {
		if a.Target == target && a.Flavor == flavor {
			return a, nil
		}
	}
	return Asset{}, fmt.Errorf("release does not provide %s/%s", target, flavor)
}

// VerifyFile verifies size and digest before an archive is extracted.
func VerifyFile(path string, asset Asset) error {
	f, err := os.Open(path)
	if err != nil {
		return fmt.Errorf("open archive: %w", err)
	}
	defer f.Close()
	info, err := f.Stat()
	if err != nil {
		return fmt.Errorf("stat archive: %w", err)
	}
	if info.Size() != asset.Size {
		return fmt.Errorf("archive size mismatch")
	}
	h := sha256.New()
	if _, err := io.Copy(h, f); err != nil {
		return fmt.Errorf("hash archive: %w", err)
	}
	if hex.EncodeToString(h.Sum(nil)) != asset.SHA256 {
		return fmt.Errorf("archive digest mismatch")
	}
	return nil
}

// FileSHA256 returns the lower-case SHA-256 digest of a file.
func FileSHA256(path string) (string, error) {
	f, err := os.Open(path)
	if err != nil {
		return "", err
	}
	defer f.Close()
	h := sha256.New()
	if _, err := io.Copy(h, f); err != nil {
		return "", err
	}
	return hex.EncodeToString(h.Sum(nil)), nil
}
