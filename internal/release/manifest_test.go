package release

import (
	"crypto/ed25519"
	"crypto/rand"
	"encoding/base64"
	"testing"
)

func TestManifestSignatureAndSelection(t *testing.T) {
	pub, private, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	raw := []byte(`{"schema_version":1,"repository":"jeeftor/airgap-dev-kit","version":"v2.0.0","channel":"stable","minimum_updater_version":"v2.0.0","artifacts":[{"target":"linux/amd64","flavor":"cli","name":"airgap-dev-kit-cli-linux-x86_64.tar.gz","size":1,"sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}]}`)
	if err := VerifySignature(raw, ed25519.Sign(private, raw), []string{base64.StdEncoding.EncodeToString(pub)}); err != nil {
		t.Fatal(err)
	}
	m, err := Parse(raw)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := m.Select("linux/amd64", "cli"); err != nil {
		t.Fatal(err)
	}
	if _, err := m.Select("linux/arm64", "cli"); err == nil {
		t.Fatal("selection unexpectedly succeeded")
	}
}
