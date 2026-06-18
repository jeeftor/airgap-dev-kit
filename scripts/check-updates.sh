#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAKEFILE="$ROOT_DIR/Makefile"
SUMMARY_FILE=""
FAIL_ON_OUTDATED=0

usage() {
  cat <<EOF
Usage: scripts/check-updates.sh [options]

Options:
  --summary-file <path>   Write Markdown summary to this file
  --fail-on-outdated      Exit with status 1 if any tool is outdated
  -h, --help              Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --summary-file)
      SUMMARY_FILE="$2"
      shift 2
      ;;
    --fail-on-outdated)
      FAIL_ON_OUTDATED=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ ! -f "$MAKEFILE" ]]; then
  echo "Makefile not found at $MAKEFILE" >&2
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required to check for updates" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required to parse GitHub release responses" >&2
  exit 1
fi

strip_whitespace() {
  echo "$1" | awk '{$1=$1;print}'
}

read_version_from_makefile() {
  local var="$1"
  local value
  value=$(grep -E "^${var}[[:space:]]*:=" "$MAKEFILE" | head -1 | awk -F':=' '{print $2}')
  strip_whitespace "${value:-}"
}

fetch_latest_tag() {
  local repo="$1"
  local tag
  tag=$(curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" \
    | python3 -c 'import json,sys; print(json.load(sys.stdin).get("tag_name",""))' 2>/dev/null || true)
  strip_whitespace "${tag:-}"
}

TOOLS=(
  "WEZTERM_VERSION|WezTerm|wez/wezterm|none"
  "FZF_VERSION|fzf|junegunn/fzf|strip_v"
  "TMUX_VERSION|tmux|nelsonenzo/tmux-appimage|none"
  "NERD_FONT_VERSION|JetBrainsMono Nerd Font|ryanoasis/nerd-fonts|none"
  "BTOP_VERSION|btop|aristocratos/btop|none"
  "LSD_VERSION|lsd|lsd-rs/lsd|none"
  "ZOX_VERSION|zoxide|ajeetdsouza/zoxide|none"
  "DELTA_VERSION|delta|dandavison/delta|none"
  "DIFFTASTIC_VERSION|difftastic|Wilfred/difftastic|none"
  "GUM_VERSION|gum|charmbracelet/gum|none"
  "DUST_VERSION|dust|bootandy/dust|none"
  "DIRENV_VERSION|direnv|direnv/direnv|none"
  "SVU_VERSION|svu|caarlos0/svu|strip_v"
)

report_header=$'| Tool | Current | Latest | Status |\n| --- | --- | --- | --- |'
report_rows=()
outdated_count=0

for entry in "${TOOLS[@]}"; do
  IFS="|" read -r var pretty repo transform <<<"$entry"

  current_version=$(read_version_from_makefile "$var")
  if [[ -z "$current_version" ]]; then
    report_rows+=("| $pretty | (missing) | ? | ⚠️ could not read $var |")
    continue
  fi

  latest_tag=$(fetch_latest_tag "$repo")
  if [[ -z "$latest_tag" ]]; then
    report_rows+=("| $pretty | $current_version | (unknown) | ⚠️ failed to fetch |")
    continue
  fi

  latest_version="$latest_tag"
  if [[ "$transform" == "strip_v" ]]; then
    latest_version="${latest_tag#v}"
  fi

  if [[ "$latest_version" == "$current_version" ]]; then
    report_rows+=("| $pretty | $current_version | $latest_version | ✅ up-to-date |")
  else
    report_rows+=("| $pretty | $current_version | $latest_version | 🔁 update available |")
    ((outdated_count += 1))
  fi
done

output="$report_header"$'\n'"$(printf '%s\n' "${report_rows[@]}")"

echo ""
echo "Version check summary"
echo "====================="
echo "$output"
echo ""
if [[ $outdated_count -gt 0 ]]; then
  echo "Found $outdated_count tool(s) with newer releases."
else
  echo "All tracked tools are up-to-date."
fi

if [[ -n "$SUMMARY_FILE" ]]; then
  printf "## Airgap Dev Kit Version Check\n\n" > "$SUMMARY_FILE"
  printf "%s\n\n" "$output" >> "$SUMMARY_FILE"
  if [[ $outdated_count -gt 0 ]]; then
    printf "Found %d tool(s) with updates available.\n" "$outdated_count" >> "$SUMMARY_FILE"
  else
    printf "All tracked tools are up-to-date.\n" >> "$SUMMARY_FILE"
  fi
fi

if [[ $outdated_count -gt 0 && $FAIL_ON_OUTDATED -eq 1 ]]; then
  exit 1
fi
