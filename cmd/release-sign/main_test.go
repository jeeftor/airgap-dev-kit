package main

import (
	"crypto/ed25519"
	"encoding/base64"
	"os"
	"path/filepath"
	"testing"

	"github.com/jeeftor/airgap-dev-kit/internal/release"
)

func TestKeygenAndSign(t *testing.T) {
	dir := t.TempDir()
	privatePath := filepath.Join(dir, "private.b64")
	publicPath := filepath.Join(dir, "public.b64")
	archive := filepath.Join(dir, "airgap-dev-kit-linux-x86_64.tar.gz")
	manifestPath := filepath.Join(dir, "release-manifest.json")
	signaturePath := filepath.Join(dir, "release-manifest.sig")
	if err := os.WriteFile(archive, []byte("release archive"), 0600); err != nil {
		t.Fatal(err)
	}
	keygen([]string{"--private-key-file", privatePath, "--public-key-file", publicPath})
	sign([]string{"--private-key-file", privatePath, "--repository", "jeeftor/airgap-dev-kit", "--version", "v2.1.3", "--archive", archive, "--manifest", manifestPath, "--signature", signaturePath})
	raw, err := os.ReadFile(manifestPath)
	if err != nil {
		t.Fatal(err)
	}
	signature, err := os.ReadFile(signaturePath)
	if err != nil {
		t.Fatal(err)
	}
	public, err := os.ReadFile(publicPath)
	if err != nil {
		t.Fatal(err)
	}
	if err := release.VerifySignature(raw, signature, []string{string(public)}); err != nil {
		t.Fatal(err)
	}
	manifest, err := release.Parse(raw)
	if err != nil {
		t.Fatal(err)
	}
	if manifest.Version != "v2.1.3" {
		t.Fatalf("version = %q", manifest.Version)
	}
	if len(manifest.Artifacts) != 1 || manifest.Artifacts[0].Size != int64(len("release archive")) {
		t.Fatalf("unexpected artifacts: %#v", manifest.Artifacts)
	}
	decoded, err := base64.StdEncoding.DecodeString(string(trim(public)))
	if err != nil || len(decoded) != ed25519.PublicKeySize {
		t.Fatalf("invalid public key")
	}
}
