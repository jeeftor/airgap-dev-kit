package cli

import (
	"context"
	"crypto/ed25519"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/jeeftor/airgap-dev-kit/internal/release"
	"github.com/spf13/cobra"
)

func TestFetchManifestSkipsLegacyRelease(t *testing.T) {
	public, private, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	original := releasePublicKeys
	releasePublicKeys = []string{base64.StdEncoding.EncodeToString(public)}
	t.Cleanup(func() { releasePublicKeys = original })
	manifest := release.Manifest{SchemaVersion: release.SchemaVersion, Repository: "example/kit", Version: "v2.1.4", Channel: "stable", MinimumUpdater: "v2.1.4", Artifacts: []release.Asset{{Target: "linux/amd64", Flavor: "full", Name: "airgap-dev-kit-linux-x86_64.tar.gz", Size: 1, SHA256: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}}}
	raw, err := json.Marshal(manifest)
	if err != nil {
		t.Fatal(err)
	}
	signature := []byte(base64.StdEncoding.EncodeToString(ed25519.Sign(private, raw)))
	var server *httptest.Server
	server = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/repos/example/kit/releases":
			fmt.Fprint(w, `[{"tag_name":"build-99","assets":[]},{"tag_name":"v2.1.4","assets":[{"name":"release-manifest.json","browser_download_url":"`+server.URL+`/manifest"},{"name":"release-manifest.sig","browser_download_url":"`+server.URL+`/signature"},{"name":"airgap-dev-kit-linux-x86_64.tar.gz","browser_download_url":"`+server.URL+`/archive"}]}]`)
		case "/manifest":
			_, _ = w.Write(raw)
		case "/signature":
			_, _ = w.Write(signature)
		default:
			http.NotFound(w, r)
		}
	}))
	defer server.Close()
	t.Setenv("AIRGAP_DEV_KIT_API_URL", server.URL)
	t.Setenv("AIRGAP_DEV_KIT_REPO", "example/kit")
	cmd := &cobra.Command{}
	cmd.SetContext(context.Background())
	got, assets, err := fetchManifest(cmd)
	if err != nil {
		t.Fatal(err)
	}
	if got.Version != "v2.1.4" || assets["airgap-dev-kit-linux-x86_64.tar.gz"] == "" {
		t.Fatalf("unexpected release: %#v, %#v", got, assets)
	}
}
