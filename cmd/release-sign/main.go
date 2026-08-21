// Command release-sign creates and signs trusted release metadata.
package main

import (
	"crypto/ed25519"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"strings"

	"github.com/jeeftor/airgap-dev-kit/internal/release"
)

func main() {
	if len(os.Args) < 2 {
		fail("usage: release-sign <keygen|sign>")
	}
	switch os.Args[1] {
	case "keygen":
		keygen(os.Args[2:])
	case "sign":
		sign(os.Args[2:])
	default:
		fail("unknown command %q", os.Args[1])
	}
}

func keygen(args []string) {
	fs := flag.NewFlagSet("keygen", flag.ExitOnError)
	privatePath := fs.String("private-key-file", "", "private key output")
	publicPath := fs.String("public-key-file", "", "public key output")
	fs.Parse(args)
	if *privatePath == "" || *publicPath == "" {
		fail("both key output paths are required")
	}
	public, private, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		fail("generate key: %v", err)
	}
	write(*privatePath, []byte(base64.StdEncoding.EncodeToString(private)+"\n"), 0600)
	write(*publicPath, []byte(base64.StdEncoding.EncodeToString(public)+"\n"), 0644)
}

func sign(args []string) {
	fs := flag.NewFlagSet("sign", flag.ExitOnError)
	keyPath := fs.String("private-key-file", "", "base64 Ed25519 private key")
	repo := fs.String("repository", "", "GitHub repository")
	version := fs.String("version", "", "release version")
	archive := fs.String("archive", "", "release archive")
	manifestPath := fs.String("manifest", "release-manifest.json", "manifest output")
	signaturePath := fs.String("signature", "release-manifest.sig", "signature output")
	fs.Parse(args)
	if *keyPath == "" || *repo == "" || *version == "" || *archive == "" {
		fail("key, repository, version, and archive are required")
	}
	encoded, err := os.ReadFile(*keyPath)
	if err != nil {
		fail("read private key: %v", err)
	}
	decoded, err := base64.StdEncoding.DecodeString(string(trim(encoded)))
	if err != nil || len(decoded) != ed25519.PrivateKeySize {
		fail("invalid Ed25519 private key")
	}
	info, err := os.Stat(*archive)
	if err != nil || info.Size() < 1 {
		fail("read archive: %v", err)
	}
	digest, err := release.FileSHA256(*archive)
	if err != nil {
		fail("hash archive: %v", err)
	}
	m := release.Manifest{SchemaVersion: release.SchemaVersion, Repository: *repo, Version: *version, Channel: "stable", MinimumUpdater: "v2.1.3", Artifacts: []release.Asset{{Target: "linux/amd64", Flavor: "full", Name: "airgap-dev-kit-linux-x86_64.tar.gz", Size: info.Size(), SHA256: digest}}}
	raw, err := json.Marshal(m)
	if err != nil {
		fail("encode manifest: %v", err)
	}
	write(*manifestPath, raw, 0644)
	sig := ed25519.Sign(ed25519.PrivateKey(decoded), raw)
	write(*signaturePath, []byte(base64.StdEncoding.EncodeToString(sig)+"\n"), 0644)
}

func trim(data []byte) string { return strings.TrimSpace(string(data)) }
func write(path string, data []byte, mode os.FileMode) {
	if err := os.WriteFile(path, data, mode); err != nil {
		fail("write %s: %v", path, err)
	}
}
func fail(format string, args ...any) { fmt.Fprintf(os.Stderr, format+"\n", args...); os.Exit(1) }
