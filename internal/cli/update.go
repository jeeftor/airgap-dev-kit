package cli

import (
	"archive/tar"
	"compress/gzip"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"time"

	"github.com/jeeftor/airgap-dev-kit/internal/release"
	"github.com/spf13/cobra"
)

const defaultRepository = "jeeftor/airgap-dev-kit"

// releasePublicKeys is intentionally compiled into the updater. Private keys
// live only in protected GitHub Actions secrets.
var releasePublicKeys = []string{"e1qJ8y9w1xiW0Y2f+C3I4psDK7XXEXnwYuXWWa+Ah98="}

type githubRelease struct {
	TagName string        `json:"tag_name"`
	Assets  []githubAsset `json:"assets"`
	Draft   bool          `json:"draft"`
}
type githubAsset struct {
	Name string `json:"name"`
	URL  string `json:"browser_download_url"`
}
type updateState struct {
	Version  string         `json:"version"`
	KitDir   string         `json:"kit_dir"`
	Rollback *rollbackState `json:"rollback,omitempty"`
}
type rollbackState struct {
	Version string `json:"version"`
	KitDir  string `json:"kit_dir"`
}

func updateCmd(currentVersion string) *cobra.Command {
	var yes bool
	root := &cobra.Command{Use: "update", Short: "Check, stage, and apply signed kit releases", RunE: func(cmd *cobra.Command, _ []string) error {
		if !yes {
			return fmt.Errorf("interactive update is not available in this non-TUI build; rerun with --yes or use update check/download/apply")
		}
		return fmt.Errorf("use 'airgap update download' then 'airgap update apply --from DIR --yes'")
	}}
	root.Flags().BoolVar(&yes, "yes", false, "Confirm the update")
	root.AddCommand(updateCheckCmd(currentVersion), updateDownloadCmd(), updateApplyCmd(), updateRollbackCmd())
	return root
}

func updateCheckCmd(currentVersion string) *cobra.Command {
	var channel string
	c := &cobra.Command{Use: "check", Short: "Check for a newer trusted release", RunE: func(cmd *cobra.Command, _ []string) error {
		m, _, err := fetchManifest(cmd)
		if err != nil {
			return err
		}
		if m.Channel != channel {
			return fmt.Errorf("latest release channel %q does not match requested %q", m.Channel, channel)
		}
		status := "current"
		if m.Version != currentVersion {
			status = "upgrade_available"
		}
		return jsonOrText(cmd, map[string]string{"installed": currentVersion, "latest": m.Version, "status": status}, fmt.Sprintf("Installed: %s\nLatest: %s\nStatus: %s\n", currentVersion, m.Version, status))
	}}
	c.Flags().StringVar(&channel, "channel", "stable", "Release channel")
	return c
}

func updateDownloadCmd() *cobra.Command {
	var version, flavor, output string
	c := &cobra.Command{Use: "download", Short: "Download a signed release into a transferable directory", RunE: func(cmd *cobra.Command, _ []string) error {
		if output == "" {
			return fmt.Errorf("--output is required")
		}
		m, assets, err := fetchManifest(cmd)
		if err != nil {
			return err
		}
		if version != "" && strings.TrimPrefix(version, "v") != strings.TrimPrefix(m.Version, "v") {
			return fmt.Errorf("requested version %s is not the latest trusted release %s", version, m.Version)
		}
		asset, err := m.Select(runtime.GOOS+"/"+runtime.GOARCH, flavor)
		if err != nil {
			return err
		}
		if err := os.MkdirAll(output, 0700); err != nil {
			return err
		}
		for _, name := range []string{"release-manifest.json", "release-manifest.sig", asset.Name} {
			if err := downloadAtomic(assets[name], filepath.Join(output, name)); err != nil {
				return err
			}
		}
		if err := release.VerifyFile(filepath.Join(output, asset.Name), asset); err != nil {
			return err
		}
		fmt.Fprintf(cmd.OutOrStdout(), "Verified %s in %s\n", asset.Name, output)
		return nil
	}}
	c.Flags().StringVar(&version, "version", "", "Exact trusted version to stage")
	c.Flags().StringVar(&flavor, "flavor", "full", "Kit flavor: full or cli")
	c.Flags().StringVar(&output, "output", "", "Transfer directory")
	return c
}

func updateApplyCmd() *cobra.Command {
	var from string
	var dryRun, yes bool
	c := &cobra.Command{Use: "apply", Short: "Apply a previously verified offline release", RunE: func(cmd *cobra.Command, _ []string) error {
		if from == "" {
			return fmt.Errorf("--from is required")
		}
		m, asset, err := verifyStaged(from)
		if err != nil {
			return err
		}
		if dryRun {
			fmt.Fprintf(cmd.OutOrStdout(), "would apply %s from %s\n", m.Version, filepath.Join(from, asset.Name))
			return nil
		}
		if !yes {
			return fmt.Errorf("update apply requires --yes unless --dry-run is used")
		}
		kit, err := stageKit(filepath.Join(from, asset.Name), m.Version)
		if err != nil {
			return err
		}
		if err := runKitInstaller(cmd, kit); err != nil {
			return err
		}
		return saveUpdateState(m.Version, kit)
	}}
	c.Flags().StringVar(&from, "from", "", "Directory created by update download")
	c.Flags().BoolVar(&dryRun, "dry-run", false, "Show the plan without mutation")
	c.Flags().BoolVar(&yes, "yes", false, "Confirm application")
	return c
}

func updateRollbackCmd() *cobra.Command {
	var yes bool
	c := &cobra.Command{Use: "rollback", Short: "Restore the immediately preceding verified kit", RunE: func(cmd *cobra.Command, _ []string) error {
		if !yes {
			return fmt.Errorf("update rollback requires --yes")
		}
		s, err := loadUpdateState()
		if err != nil {
			return err
		}
		if s.Rollback == nil {
			return fmt.Errorf("no verified rollback release is available")
		}
		if err := runKitInstaller(cmd, s.Rollback.KitDir); err != nil {
			return err
		}
		return saveUpdateState(s.Rollback.Version, s.Rollback.KitDir)
	}}
	c.Flags().BoolVar(&yes, "yes", false, "Confirm rollback")
	return c
}

func fetchManifest(cmd *cobra.Command) (release.Manifest, map[string]string, error) {
	api := strings.TrimRight(os.Getenv("AIRGAP_DEV_KIT_API_URL"), "/")
	if api == "" {
		api = "https://api.github.com"
	}
	repo := os.Getenv("AIRGAP_DEV_KIT_REPO")
	if repo == "" {
		repo = defaultRepository
	}
	req, err := http.NewRequestWithContext(cmd.Context(), http.MethodGet, api+"/repos/"+repo+"/releases", nil)
	if err != nil {
		return release.Manifest{}, nil, err
	}
	if token := os.Getenv("GITHUB_TOKEN"); token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return release.Manifest{}, nil, fmt.Errorf("fetch release: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return release.Manifest{}, nil, fmt.Errorf("fetch release: %s", resp.Status)
	}
	var releases []githubRelease
	if err := json.NewDecoder(resp.Body).Decode(&releases); err != nil {
		return release.Manifest{}, nil, err
	}
	for _, r := range releases {
		if r.Draft {
			continue
		}
		assets := map[string]string{}
		for _, a := range r.Assets {
			assets[a.Name] = a.URL
		}
		if assets["release-manifest.json"] == "" || assets["release-manifest.sig"] == "" {
			continue
		}
		raw, err := getBytes(assets["release-manifest.json"])
		if err != nil {
			return release.Manifest{}, nil, err
		}
		sig, err := getBytes(assets["release-manifest.sig"])
		if err != nil {
			return release.Manifest{}, nil, err
		}
		if err := release.VerifySignature(raw, sig, releasePublicKeys); err != nil {
			return release.Manifest{}, nil, err
		}
		m, err := release.Parse(raw)
		if err != nil {
			return release.Manifest{}, nil, err
		}
		if m.Repository != repo || (r.TagName != "" && strings.TrimPrefix(r.TagName, "v") != strings.TrimPrefix(m.Version, "v")) {
			return release.Manifest{}, nil, fmt.Errorf("release identity mismatch")
		}
		return m, assets, nil
	}
	return release.Manifest{}, nil, fmt.Errorf("no signed release is available")
}

func getBytes(url string) ([]byte, error) {
	if url == "" {
		return nil, fmt.Errorf("required release asset is missing")
	}
	resp, err := http.Get(url)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("download %s: %s", url, resp.Status)
	}
	return io.ReadAll(resp.Body)
}
func downloadAtomic(url, dst string) error {
	raw, err := getBytes(url)
	if err != nil {
		return err
	}
	part := dst + ".part"
	if err := os.WriteFile(part, raw, 0600); err != nil {
		return err
	}
	return os.Rename(part, dst)
}

func verifyStaged(dir string) (release.Manifest, release.Asset, error) {
	raw, err := os.ReadFile(filepath.Join(dir, "release-manifest.json"))
	if err != nil {
		return release.Manifest{}, release.Asset{}, err
	}
	sig, err := os.ReadFile(filepath.Join(dir, "release-manifest.sig"))
	if err != nil {
		return release.Manifest{}, release.Asset{}, err
	}
	if err := release.VerifySignature(raw, sig, releasePublicKeys); err != nil {
		return release.Manifest{}, release.Asset{}, err
	}
	m, err := release.Parse(raw)
	if err != nil {
		return release.Manifest{}, release.Asset{}, err
	}
	for _, flavor := range []string{"full", "cli"} {
		a, selectErr := m.Select(runtime.GOOS+"/"+runtime.GOARCH, flavor)
		if selectErr == nil {
			if _, statErr := os.Stat(filepath.Join(dir, a.Name)); statErr == nil {
				if err := release.VerifyFile(filepath.Join(dir, a.Name), a); err != nil {
					return release.Manifest{}, release.Asset{}, err
				}
				return m, a, nil
			}
		}
	}
	return release.Manifest{}, release.Asset{}, fmt.Errorf("staged directory has no matching target archive")
}

func stageKit(archive, version string) (string, error) {
	data, err := dataDir()
	if err != nil {
		return "", err
	}
	kits := filepath.Join(data, "airgap-dev-kit", "kits")
	if err := os.MkdirAll(kits, 0700); err != nil {
		return "", err
	}
	stage, err := os.MkdirTemp(kits, ".stage-")
	if err != nil {
		return "", err
	}
	if err := extractSafeTarGz(archive, stage); err != nil {
		_ = os.RemoveAll(stage)
		return "", err
	}
	entries, err := os.ReadDir(stage)
	if err != nil || len(entries) != 1 || !entries[0].IsDir() {
		_ = os.RemoveAll(stage)
		return "", fmt.Errorf("release archive must contain one top-level directory")
	}
	root := filepath.Join(stage, entries[0].Name())
	if _, _, err := readKitManifest(root); err != nil {
		_ = os.RemoveAll(stage)
		return "", fmt.Errorf("release package has no valid v2 manifest: %w", err)
	}
	final := filepath.Join(kits, strings.TrimPrefix(version, "v")+"-"+time.Now().UTC().Format("20060102150405"))
	if err := os.Rename(root, final); err != nil {
		_ = os.RemoveAll(stage)
		return "", err
	}
	_ = os.Remove(stage)
	return final, nil
}

func dataDir() (string, error) {
	if value := os.Getenv("XDG_DATA_HOME"); value != "" {
		return value, nil
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(home, ".local", "share"), nil
}

func extractSafeTarGz(archive, dst string) error {
	f, err := os.Open(archive)
	if err != nil {
		return err
	}
	defer f.Close()
	gz, err := gzip.NewReader(f)
	if err != nil {
		return err
	}
	defer gz.Close()
	tr := tar.NewReader(gz)
	for {
		h, err := tr.Next()
		if err == io.EOF {
			return nil
		}
		if err != nil {
			return err
		}
		clean := filepath.Clean(h.Name)
		if filepath.IsAbs(h.Name) || clean == "." || strings.HasPrefix(clean, ".."+string(filepath.Separator)) {
			return fmt.Errorf("unsafe archive path %q", h.Name)
		}
		target := filepath.Join(dst, clean)
		if h.Typeflag != tar.TypeDir && h.Typeflag != tar.TypeReg && h.Typeflag != tar.TypeSymlink {
			return fmt.Errorf("unsafe archive entry %q", h.Name)
		}
		if h.Typeflag == tar.TypeDir {
			if err := os.MkdirAll(target, 0755); err != nil {
				return err
			}
			continue
		}
		if err := os.MkdirAll(filepath.Dir(target), 0755); err != nil {
			return err
		}
		if h.Typeflag == tar.TypeSymlink {
			resolvedLink := filepath.Clean(filepath.Join(filepath.Dir(clean), h.Linkname))
			if filepath.IsAbs(h.Linkname) || resolvedLink == "." || strings.HasPrefix(resolvedLink, ".."+string(filepath.Separator)) {
				return fmt.Errorf("unsafe archive link %q", h.Linkname)
			}
			if err := os.Symlink(h.Linkname, target); err != nil {
				return err
			}
			continue
		}
		out, err := os.OpenFile(target, os.O_WRONLY|os.O_CREATE|os.O_EXCL, os.FileMode(h.Mode)&0755)
		if err != nil {
			return err
		}
		_, copyErr := io.Copy(out, tr)
		closeErr := out.Close()
		if copyErr != nil {
			return copyErr
		}
		if closeErr != nil {
			return closeErr
		}
	}
}

func runKitInstaller(cmd *cobra.Command, kit string) error {
	previous := os.Getenv("AIRGAP_KIT_DIR")
	if err := os.Setenv("AIRGAP_KIT_DIR", kit); err != nil {
		return err
	}
	defer os.Setenv("AIRGAP_KIT_DIR", previous)
	return installKit(cmd, installOptions{Yes: true, NvimMode: "preserve"})
}

func statePath() (string, error) {
	if state := os.Getenv("XDG_STATE_HOME"); state != "" {
		return filepath.Join(state, "airgap-dev-kit", "current.json"), nil
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(home, ".local", "state", "airgap-dev-kit", "current.json"), nil
}
func loadUpdateState() (updateState, error) {
	p, err := statePath()
	if err != nil {
		return updateState{}, err
	}
	raw, err := os.ReadFile(p)
	if err != nil {
		return updateState{}, err
	}
	var s updateState
	return s, json.Unmarshal(raw, &s)
}
func saveUpdateState(version, kit string) error {
	p, err := statePath()
	if err != nil {
		return err
	}
	_ = os.MkdirAll(filepath.Dir(p), 0700)
	prior, _ := loadUpdateState()
	s := updateState{Version: version, KitDir: kit}
	if prior.KitDir != "" && prior.KitDir != kit {
		s.Rollback = &rollbackState{Version: prior.Version, KitDir: prior.KitDir}
	}
	raw, err := json.Marshal(s)
	if err != nil {
		return err
	}
	tmp := p + "." + time.Now().UTC().Format("20060102150405") + ".tmp"
	if err := os.WriteFile(tmp, raw, 0600); err != nil {
		return err
	}
	return os.Rename(tmp, p)
}
