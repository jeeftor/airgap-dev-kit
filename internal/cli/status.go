package cli

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
)

// installedComponent describes one path created by the native installer.
type installedComponent struct {
	Path    string `json:"path"`
	Kind    string `json:"kind"`
	Status  string `json:"status"`
	PathHit string `json:"path_hit,omitempty"`
}

type statusReport struct {
	KitDir        string               `json:"kit_dir"`
	KitAvailable  bool                 `json:"kit_available"`
	Executable    string               `json:"executable"`
	Target        string               `json:"target"`
	RecordPath    string               `json:"record_path"`
	RecordFound   bool                 `json:"record_found"`
	Version       string               `json:"installed_version,omitempty"`
	InstalledFrom string               `json:"installed_from,omitempty"`
	Components    []installedComponent `json:"components"`
	Applications  []kitApplication     `json:"applications"`
	Fonts         []installedComponent `json:"fonts"`
}

// kitApplication is one executable that the extracted kit can install.
type kitApplication struct {
	Name        string `json:"name"`
	Source      string `json:"source"`
	Destination string `json:"destination"`
	Status      string `json:"status"`
}

// installationStatus reads the native installer record and reports the current
// filesystem and PATH state without changing the host.
func installationStatus() (statusReport, error) {
	recordPath, err := installRecordPath()
	if err != nil {
		return statusReport{}, err
	}
	report := statusReport{RecordPath: recordPath}
	raw, err := os.ReadFile(recordPath)
	if os.IsNotExist(err) {
		return report, nil
	}
	if err != nil {
		return statusReport{}, fmt.Errorf("read installation record: %w", err)
	}
	var record installRecord
	if err := json.Unmarshal(raw, &record); err != nil {
		return statusReport{}, fmt.Errorf("read installation record: invalid JSON: %w", err)
	}
	report.RecordFound = true
	report.Version = record.Version
	report.InstalledFrom = record.KitDir
	for _, path := range record.Paths {
		report.Components = append(report.Components, inspectInstalledPath(path))
	}
	for _, path := range record.ShellRCs {
		report.Components = append(report.Components, inspectShellRC(path))
	}
	return report, nil
}

func inspectInstalledPath(path string) installedComponent {
	component := installedComponent{Path: path, Kind: "path", Status: "missing"}
	info, err := os.Stat(path)
	if os.IsNotExist(err) {
		return component
	}
	if err != nil {
		component.Status = "unreadable"
		return component
	}
	component.Status = "installed"
	switch {
	case info.IsDir():
		component.Kind = "directory"
	case info.Mode()&0111 != 0:
		component.Kind = "binary"
		if resolved, err := exec.LookPath(filepath.Base(path)); err == nil {
			component.PathHit = resolved
		}
	default:
		component.Kind = "file"
	}
	return component
}

func inspectShellRC(path string) installedComponent {
	component := inspectInstalledPath(path)
	component.Kind = "shell startup file"
	if component.Status != "installed" {
		return component
	}
	raw, err := os.ReadFile(path)
	if err != nil || !strings.Contains(string(raw), shellBlockStart) {
		component.Status = "managed block missing"
	}
	return component
}

// addKitApplications lists every executable payload and marks whether the
// native installer recorded it as installed on this host.
func (r *statusReport) addKitApplications() error {
	if !r.KitAvailable {
		return nil
	}
	_, payload, err := readKitManifest(r.KitDir)
	if err != nil {
		return err
	}
	entries, err := os.ReadDir(payload)
	if err != nil {
		return fmt.Errorf("read kit payload: %w", err)
	}
	recorded := make(map[string]bool, len(r.Components))
	for _, component := range r.Components {
		recorded[component.Path] = component.Status == "installed"
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return err
	}
	binDir := filepath.Join(home, ".local", "bin")
	for _, entry := range entries {
		info, err := entry.Info()
		if err != nil || entry.IsDir() || !info.Mode().IsRegular() || info.Mode()&0111 == 0 || entry.Name() == "airgap-dev-kit" {
			continue
		}
		name, destination := entry.Name(), entry.Name()
		if name == "wezterm.AppImage" {
			destination = "wezterm"
		}
		if name == "nvim-static-x86_64" {
			name, destination = "nvim", "nvim-airgap"
		}
		path := filepath.Join(binDir, destination)
		status := "not installed"
		if recorded[path] {
			status = "installed"
		} else if executable(path) {
			status = "untracked"
		}
		r.Applications = append(r.Applications, kitApplication{Name: name, Source: filepath.Join(payload, entry.Name()), Destination: path, Status: status})
	}
	sort.Slice(r.Applications, func(i, j int) bool { return r.Applications[i].Name < r.Applications[j].Name })
	r.Fonts = append(r.Fonts, inspectInstalledPath(filepath.Join(home, ".local", "share", "fonts", "JetBrainsMono")))
	return nil
}

func (r statusReport) text(kitDir string) string {
	if statusTableEnabled() {
		return r.terminalText(kitDir)
	}
	var b strings.Builder
	fmt.Fprintln(&b, "Airgap status")
	fmt.Fprintln(&b, "Executable: "+r.Executable)
	fmt.Fprintln(&b, "Kit directory: "+kitDir)
	fmt.Fprintf(&b, "Kit available: %t\n", r.KitAvailable)
	fmt.Fprintln(&b, "Target: "+r.Target)
	fmt.Fprintln(&b, "Installation record: "+r.RecordPath)
	if !r.RecordFound {
		fmt.Fprintln(&b, "Recorded installation: not found (run airgap install to create one)")
	} else {
		fmt.Fprintln(&b, "Installed version: "+r.Version)
		fmt.Fprintln(&b, "Installed from: "+r.InstalledFrom)
		fmt.Fprintln(&b, "Recorded components:")
		for _, component := range r.Components {
			line := fmt.Sprintf("  [%s] %s — %s", strings.ToUpper(component.Status), component.Kind, component.Path)
			if component.Kind == "binary" {
				if component.PathHit == "" {
					line += "; not found on PATH"
				} else {
					line += "; PATH resolves to " + component.PathHit
				}
			}
			fmt.Fprintln(&b, line)
		}
	}
	if len(r.Applications) > 0 {
		fmt.Fprintln(&b, "Kit applications:")
		for _, application := range r.Applications {
			fmt.Fprintf(&b, "  [%s] %s — source %s; destination %s\n", strings.ToUpper(application.Status), application.Name, application.Source, application.Destination)
		}
	}
	for _, font := range r.Fonts {
		fmt.Fprintf(&b, "Nerd Fonts: [%s] %s\n", strings.ToUpper(font.Status), font.Path)
	}
	return b.String()
}
