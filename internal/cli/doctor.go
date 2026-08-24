package cli

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"charm.land/lipgloss/v2"
	"github.com/spf13/cobra"
	"github.com/spf13/viper"
)

type doctorCheck struct {
	Name   string `json:"name"`
	Status string `json:"status"`
	Detail string `json:"detail"`
}

type doctorReport struct {
	KitDir         string        `json:"kit_dir"`
	Layout         string        `json:"layout"`
	RuntimeVersion string        `json:"runtime_version"`
	RuntimeCommit  string        `json:"runtime_commit"`
	Checks         []doctorCheck `json:"checks"`
	Passed         int           `json:"passed"`
	Warnings       int           `json:"warnings"`
	Failures       int           `json:"failures"`
}

type kitManifest struct {
	SchemaVersion int    `json:"schema_version"`
	Version       string `json:"version"`
	Target        string `json:"target"`
	PayloadDir    string `json:"payload_dir"`
}

// doctorCmd reports whether an extracted kit has the files needed for an offline install.
func doctorCmd(output *string, version, commit string) *cobra.Command {
	var strict, verify bool
	c := &cobra.Command{Use: "doctor", Short: "Diagnose an extracted kit without network access", RunE: func(cmd *cobra.Command, _ []string) error {
		root, found := discoveredKitRoot()
		report := diagnoseKit(root, found, version, commit)
		if err := writeDoctorReport(cmd, report); err != nil {
			return err
		}
		if verify && report.Failures > 0 {
			return fmt.Errorf("doctor found %d failed check(s)", report.Failures)
		}
		if strict && (report.Failures > 0 || report.Warnings > 0) {
			return fmt.Errorf("doctor found %d warning(s) and %d failed check(s)", report.Warnings, report.Failures)
		}
		return nil
	}}
	c.Flags().BoolVar(&strict, "strict", false, "Fail if any warning or check failure is found")
	c.Flags().BoolVar(&verify, "verify", false, "Fail if a required kit component is missing or invalid")
	return c
}

// writeDoctorReport renders structured JSON or a color-coded terminal report.
func writeDoctorReport(cmd *cobra.Command, report doctorReport) error {
	if viper.GetString("output") != "text" {
		return jsonOrText(cmd, report, report.text())
	}
	if !colorEnabled(cmd) {
		return writeDoctorPlainReport(cmd, report)
	}
	return writeDoctorTerminalReport(cmd, report)
}

// writeDoctorPlainReport keeps redirected and NO_COLOR output compact and readable.
func writeDoctorPlainReport(cmd *cobra.Command, report doctorReport) error {
	kitDir := report.KitDir
	if kitDir == "" {
		kitDir = "not found"
	}
	var b strings.Builder
	fmt.Fprintln(&b, styled(cmd, titleStyle, "Airgap doctor"))
	fmt.Fprintln(&b, "Kit directory: "+styled(cmd, pathStyle, kitDir))
	if report.Layout != "" {
		fmt.Fprintln(&b, "Layout: "+styled(cmd, dimStyle, report.Layout))
	}
	failureStyle := failStyle
	if report.Failures == 0 {
		failureStyle = dimStyle
	}
	fmt.Fprintln(&b, "Summary: "+styled(cmd, okStyle, fmt.Sprintf("✓ %d passed", report.Passed))+", "+styled(cmd, warnStyle, fmt.Sprintf("⚠ %d warning(s)", report.Warnings))+", "+styled(cmd, failureStyle, fmt.Sprintf("✗ %d failure(s)", report.Failures)))
	for _, check := range report.Checks {
		fmt.Fprintln(&b, doctorStatusStyle(cmd, check.Status, doctorStatusLabel(check.Status))+" "+check.Name+" — "+doctorDetail(cmd, check.Detail))
	}
	overall := "HEALTHY"
	overallStyle := okStyle
	if report.Failures > 0 {
		overall = "NEEDS ATTENTION"
		overallStyle = failStyle
	} else if report.Warnings > 0 {
		overall = "READY WITH WARNINGS"
		overallStyle = warnStyle
	}
	fmt.Fprintln(&b, "Overall: "+styled(cmd, overallStyle, doctorStatusIcon(report)+" "+overall))
	_, err := fmt.Fprint(cmd.OutOrStdout(), b.String())
	return err
}

// writeDoctorTerminalReport uses Lipgloss layout only for interactive terminals.
func writeDoctorTerminalReport(cmd *cobra.Command, report doctorReport) error {
	kitDir := report.KitDir
	if kitDir == "" {
		kitDir = "not found"
	}
	keyStyle := lipgloss.NewStyle().Foreground(lipgloss.Color("245")).Width(15)
	statusColumn := lipgloss.NewStyle().Width(11)
	nameColumn := lipgloss.NewStyle().Bold(true).Width(20)

	var b strings.Builder
	fmt.Fprintln(&b, styled(cmd, titleStyle, "✦ Airgap Doctor"))
	fmt.Fprintln(&b, styled(cmd, dimStyle, "Offline kit diagnostics"))
	fmt.Fprintln(&b, styled(cmd, accentStyle, "────────────────────────────────"))
	fmt.Fprintln(&b, keyStyle.Render("Kit directory")+styled(cmd, pathStyle, kitDir))
	if report.Layout != "" {
		fmt.Fprintln(&b, keyStyle.Render("Layout")+styled(cmd, dimStyle, report.Layout))
	}

	failureStyle := failStyle
	if report.Failures == 0 {
		failureStyle = dimStyle
	}
	summary := lipgloss.JoinHorizontal(lipgloss.Top,
		styled(cmd, okStyle, fmt.Sprintf("✓ %d passed", report.Passed)),
		"   ",
		styled(cmd, warnStyle, fmt.Sprintf("⚠ %d warning(s)", report.Warnings)),
		"   ",
		styled(cmd, failureStyle, fmt.Sprintf("✗ %d failure(s)", report.Failures)),
	)
	fmt.Fprintln(&b, summary)
	fmt.Fprintln(&b, styled(cmd, accentStyle, "Checks"))
	for _, check := range report.Checks {
		row := lipgloss.JoinHorizontal(lipgloss.Top,
			statusColumn.Render(doctorStatusStyle(cmd, check.Status, doctorStatusLabel(check.Status))),
			nameColumn.Render(check.Name),
			doctorDetail(cmd, check.Detail),
		)
		fmt.Fprintln(&b, row)
	}

	overall := "HEALTHY"
	overallStyle := okStyle
	if report.Failures > 0 {
		overall = "NEEDS ATTENTION"
		overallStyle = failStyle
	} else if report.Warnings > 0 {
		overall = "READY WITH WARNINGS"
		overallStyle = warnStyle
	}
	fmt.Fprintln(&b, keyStyle.Render("Overall")+styled(cmd, overallStyle, doctorStatusIcon(report)+" "+overall))
	_, err := fmt.Fprint(cmd.OutOrStdout(), b.String())
	return err
}

// doctorDetail colors filesystem paths and kit file names while keeping prose subdued.
func doctorDetail(cmd *cobra.Command, detail string) string {
	var b strings.Builder
	for len(detail) > 0 {
		whitespace := len(detail)
		for index, r := range detail {
			if r == ' ' || r == '\t' || r == '\n' {
				whitespace = index
				break
			}
		}
		token := detail[:whitespace]
		b.WriteString(doctorDetailToken(cmd, token))
		detail = detail[whitespace:]
		for len(detail) > 0 && (detail[0] == ' ' || detail[0] == '\t' || detail[0] == '\n') {
			b.WriteByte(detail[0])
			detail = detail[1:]
		}
	}
	return b.String()
}

// doctorDetailToken chooses a style for one diagnostic detail token.
func doctorDetailToken(cmd *cobra.Command, token string) string {
	trimmed := strings.TrimRight(token, ",;.)")
	suffix := strings.TrimPrefix(token, trimmed)
	if strings.HasPrefix(trimmed, "/") || strings.HasPrefix(trimmed, "./") {
		return styled(cmd, pathStyle, trimmed) + styled(cmd, dimStyle, suffix)
	}
	switch trimmed {
	case "airgap", "airgap-dev-kit", "VERSION", "kit-manifest.json":
		return styled(cmd, fileStyle, trimmed) + styled(cmd, dimStyle, suffix)
	default:
		return styled(cmd, dimStyle, token)
	}
}

// doctorStatusLabel returns a readable symbol and status label for each check.
func doctorStatusLabel(status string) string {
	switch status {
	case "pass":
		return "[✓ PASS]"
	case "warn":
		return "[⚠ WARN]"
	default:
		return "[✗ FAIL]"
	}
}

// doctorStatusIcon returns the icon for the report's final state.
func doctorStatusIcon(report doctorReport) string {
	if report.Failures > 0 {
		return "✗"
	}
	if report.Warnings > 0 {
		return "⚠"
	}
	return "✓"
}

// doctorStatusStyle chooses the semantic style for a diagnostic status label.
func doctorStatusStyle(cmd *cobra.Command, status, value string) string {
	switch status {
	case "pass":
		return styled(cmd, okStyle, value)
	case "warn":
		return styled(cmd, warnStyle, value)
	default:
		return styled(cmd, failStyle, value)
	}
}

// diagnoseKit validates the files needed to run an offline kit without changing it.
func diagnoseKit(root string, found bool, runtimeVersion, runtimeCommit string) doctorReport {
	report := doctorReport{KitDir: root, RuntimeVersion: runtimeVersion, RuntimeCommit: runtimeCommit}
	if !found {
		report.add("kit root", "fail", "not found; run from the extracted kit or set AIRGAP_KIT_DIR")
		return report
	}
	report.add("kit root", "pass", root)

	versionPath := filepath.Join(root, "VERSION")
	version, err := os.ReadFile(versionPath)
	if err != nil {
		report.add("kit version", "warn", "VERSION is missing; running "+runtimeIdentity(runtimeVersion, runtimeCommit))
	} else if value := strings.TrimSpace(string(version)); value == "" {
		report.add("kit version", "warn", "VERSION is empty; running "+runtimeIdentity(runtimeVersion, runtimeCommit))
	} else if strings.Contains(value, "-dirty") {
		report.add("kit version", "warn", value+" (built from a dirty worktree)")
	} else if runtimeVersion != "" && runtimeVersion != "dev" && runtimeVersion != value {
		report.add("kit version", "warn", "kit is "+value+" but running binary is "+runtimeIdentity(runtimeVersion, runtimeCommit))
	} else {
		report.add("kit version", "pass", value)
	}

	payloadDir := filepath.Join(root, "offline-packages", "linux")
	manifestPath := filepath.Join(root, "kit-manifest.json")
	if raw, err := os.ReadFile(manifestPath); err == nil {
		var manifest kitManifest
		if err := json.Unmarshal(raw, &manifest); err != nil || manifest.SchemaVersion != 1 || manifest.PayloadDir == "" || filepath.IsAbs(manifest.PayloadDir) || strings.HasPrefix(filepath.Clean(manifest.PayloadDir), "..") {
			report.add("kit manifest", "fail", "kit-manifest.json is invalid")
		} else {
			report.Layout = "v2 " + manifest.Target
			payloadDir = filepath.Join(root, manifest.PayloadDir)
			report.add("kit manifest", "pass", fmt.Sprintf("%s; payload %s", report.Layout, manifest.PayloadDir))
		}
	} else if os.IsNotExist(err) {
		report.Layout = "legacy"
		report.add("kit manifest", "warn", "not present; using legacy linux payload layout")
	} else {
		report.add("kit manifest", "fail", "cannot read kit-manifest.json")
	}

	info, err := os.Stat(payloadDir)
	if err != nil || !info.IsDir() {
		report.add("payload directory", "fail", payloadDir+" is missing")
		return report
	}
	entries, err := os.ReadDir(payloadDir)
	if err != nil {
		report.add("payload directory", "fail", "cannot read "+payloadDir)
		return report
	}
	report.add("payload directory", "pass", fmt.Sprintf("%s (%d entries)", payloadDir, len(entries)))

	if executable(filepath.Join(payloadDir, "airgap")) {
		report.add("lifecycle binary", "pass", "airgap is executable")
	} else if executable(filepath.Join(payloadDir, "airgap-dev-kit")) {
		report.add("lifecycle binary", "warn", "legacy airgap-dev-kit wrapper is executable; build a v2 release for airgap")
	} else {
		report.add("lifecycle binary", "fail", "airgap is missing or is not executable")
	}

	if executable(filepath.Join(root, "airgap")) {
		report.add("root launcher", "pass", "./airgap is ready to run after extraction")
	} else {
		report.add("root launcher", "warn", "./airgap is unavailable; use the payload path or build a fresh v2 release")
	}
	return report
}

// runtimeIdentity returns the version and commit embedded in the running binary.
func runtimeIdentity(version, commit string) string {
	if version == "" {
		version = "unknown"
	}
	if commit == "" || commit == "none" {
		return version
	}
	return version + " (" + commit + ")"
}

// add records a diagnostic check and maintains the report summary counts.
func (r *doctorReport) add(name, status, detail string) {
	r.Checks = append(r.Checks, doctorCheck{Name: name, Status: status, Detail: detail})
	switch status {
	case "pass":
		r.Passed++
	case "warn":
		r.Warnings++
	default:
		r.Failures++
	}
}

// text renders the report for terminals without requiring a JSON parser.
func (r doctorReport) text() string {
	kitDir := r.KitDir
	if kitDir == "" {
		kitDir = "not found"
	}
	var b strings.Builder
	fmt.Fprintln(&b, "Airgap doctor")
	fmt.Fprintln(&b, "Kit directory: "+kitDir)
	if r.Layout != "" {
		fmt.Fprintln(&b, "Layout: "+r.Layout)
	}
	fmt.Fprintf(&b, "Summary: %d passed, %d warning(s), %d failure(s)\n", r.Passed, r.Warnings, r.Failures)
	for _, check := range r.Checks {
		fmt.Fprintf(&b, "[%s] %s — %s\n", strings.ToUpper(check.Status), check.Name, check.Detail)
	}
	if r.Failures > 0 {
		fmt.Fprintln(&b, "Overall: NEEDS ATTENTION")
	} else if r.Warnings > 0 {
		fmt.Fprintln(&b, "Overall: READY WITH WARNINGS")
	} else {
		fmt.Fprintln(&b, "Overall: HEALTHY")
	}
	return b.String()
}

// executable reports whether path is a regular executable file or executable symlink target.
func executable(path string) bool {
	info, err := os.Stat(path)
	return err == nil && !info.IsDir() && info.Mode()&0111 != 0
}
