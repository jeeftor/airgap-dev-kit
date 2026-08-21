package cli

import (
	"archive/tar"
	"compress/gzip"
	"context"
	"crypto/ed25519"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
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

func TestExtractSafeTarGzAcceptsRelativeSymlinks(t *testing.T) {
	archive := filepath.Join(t.TempDir(), "payload.tar.gz")
	file, err := os.Create(archive)
	if err != nil {
		t.Fatal(err)
	}
	gz := gzip.NewWriter(file)
	tw := tar.NewWriter(gz)
	if err := tw.WriteHeader(&tar.Header{Name: "lazy/target", Mode: 0644, Size: 2}); err != nil {
		t.Fatal(err)
	}
	if _, err := tw.Write([]byte("ok")); err != nil {
		t.Fatal(err)
	}
	if err := tw.WriteHeader(&tar.Header{Name: "lazy/link", Typeflag: tar.TypeSymlink, Linkname: "target"}); err != nil {
		t.Fatal(err)
	}
	if err := tw.Close(); err != nil {
		t.Fatal(err)
	}
	if err := gz.Close(); err != nil {
		t.Fatal(err)
	}
	if err := file.Close(); err != nil {
		t.Fatal(err)
	}
	destination := t.TempDir()
	if err := extractSafeTarGz(archive, destination); err != nil {
		t.Fatal(err)
	}
	link, err := os.Readlink(filepath.Join(destination, "lazy", "link"))
	if err != nil || link != "target" {
		t.Fatalf("relative symlink = %q, %v", link, err)
	}
}

func TestExtractSafeTarGzRejectsEscapingSymlink(t *testing.T) {
	archive := filepath.Join(t.TempDir(), "payload.tar.gz")
	file, err := os.Create(archive)
	if err != nil {
		t.Fatal(err)
	}
	gz := gzip.NewWriter(file)
	tw := tar.NewWriter(gz)
	if err := tw.WriteHeader(&tar.Header{Name: "lazy/link", Typeflag: tar.TypeSymlink, Linkname: "../../outside"}); err != nil {
		t.Fatal(err)
	}
	if err := tw.Close(); err != nil {
		t.Fatal(err)
	}
	if err := gz.Close(); err != nil {
		t.Fatal(err)
	}
	if err := file.Close(); err != nil {
		t.Fatal(err)
	}
	if err := extractSafeTarGz(archive, t.TempDir()); err == nil {
		t.Fatal("escaping symlink was accepted")
	}
}
