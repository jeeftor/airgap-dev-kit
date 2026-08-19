#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAKEFILE="${AIRGAP_DEV_KIT_MAKEFILE:-$ROOT_DIR/Makefile}"
SUMMARY_FILE=""
JSON_FILE=""
APPLY_TOOL=""
APPLY_VERSION=""
FAIL_ON_OUTDATED=0

usage() {
  cat <<EOF
Usage: scripts/check-updates.sh [options]

Options:
  --makefile <path>       Read or update this Makefile instead of ./Makefile
  --summary-file <path>   Write Markdown summary to this file
  --json-file <path>      Write outdated tool records as JSON
  --apply-tool <tool>     Update one tracked tool version in the Makefile
  --version <version>     Version to use with --apply-tool
  --fail-on-outdated      Exit with status 1 if any tool is outdated
  -h, --help              Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --makefile)
      MAKEFILE="$2"
      shift 2
      ;;
    --summary-file)
      SUMMARY_FILE="$2"
      shift 2
      ;;
    --json-file)
      JSON_FILE="$2"
      shift 2
      ;;
    --apply-tool)
      APPLY_TOOL="$2"
      shift 2
      ;;
    --version)
      APPLY_VERSION="$2"
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

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required to parse GitHub release responses" >&2
  exit 1
fi

TOOLS=(
  "wezterm|WEZTERM_VERSION|WezTerm|wez/wezterm|none"
  "fzf|FZF_VERSION|fzf|junegunn/fzf|strip_v"
  "tmux|TMUX_VERSION|tmux|nelsonenzo/tmux-appimage|none"
  "neovim|NVIM_VERSION|Neovim|neovim/neovim|none"
  "jetbrainsmono-nerd-font|NERD_FONT_VERSION|JetBrainsMono Nerd Font|ryanoasis/nerd-fonts|none"
  "btop|BTOP_VERSION|btop|aristocratos/btop|none"
  "lsd|LSD_VERSION|lsd|lsd-rs/lsd|none"
  "zoxide|ZOX_VERSION|zoxide|ajeetdsouza/zoxide|none"
  "delta|DELTA_VERSION|delta|dandavison/delta|none"
  "difftastic|DIFFTASTIC_VERSION|difftastic|Wilfred/difftastic|none"
  "gum|GUM_VERSION|gum|charmbracelet/gum|none"
  "glow|GLOW_VERSION|glow|charmbracelet/glow|none"
  "dust|DUST_VERSION|dust|bootandy/dust|none"
  "gdu|GDU_VERSION|gdu|dundee/gdu|none"
  "usbtree|USBTREE_VERSION|usbtree|gnomeria/usbtree|none"
  "mkcert|MKCERT_VERSION|mkcert|FiloSottile/mkcert|none"
  "direnv|DIRENV_VERSION|direnv|direnv/direnv|none"
  "svu|SVU_VERSION|svu|caarlos0/svu|strip_v"
  "gping|GPING_VERSION|gping|orf/gping|strip_gping_v"
  "fd|FD_VERSION|fd|sharkdp/fd|strip_v"
  "ripgrep|RG_VERSION|ripgrep|BurntSushi/ripgrep|none"
  "bat|BAT_VERSION|bat|sharkdp/bat|strip_v"
  "starship|STARSHIP_VERSION|starship|starship/starship|strip_v"
)

strip_whitespace() {
  echo "$1" | awk '{$1=$1;print}'
}

read_version_from_makefile() {
  local var="$1"
  local value
  value=$(grep -E "^${var}[[:space:]]*:=" "$MAKEFILE" | head -1 | awk -F':=' '{print $2}' || true)
  strip_whitespace "${value:-}"
}

fetch_latest_tag() {
  local repo="$1"
  local repo_key="${repo//\//__}"
  local tag
  if [[ -n "${AIRGAP_DEV_KIT_RELEASES_DIR:-}" ]]; then
    tag=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8")).get("tag_name",""))' \
      "${AIRGAP_DEV_KIT_RELEASES_DIR}/${repo_key}.json" 2>/dev/null || true)
  else
    tag=$(curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" \
      | python3 -c 'import json,sys; print(json.load(sys.stdin).get("tag_name",""))' 2>/dev/null || true)
  fi
  strip_whitespace "${tag:-}"
}

apply_tool_update() {
  local tool="$1"
  local version="$2"
  local var=""
  local entry slug candidate_var _pretty _repo _transform

  for entry in "${TOOLS[@]}"; do
    IFS="|" read -r slug candidate_var _pretty _repo _transform <<<"$entry"
    if [[ "$slug" == "$tool" ]]; then
      var="$candidate_var"
      break
    fi
  done

  if [[ -z "$var" ]]; then
    echo "Unknown tracked tool: $tool" >&2
    exit 1
  fi

  python3 - "$MAKEFILE" "$var" "$version" <<'PY'
import sys

makefile, var, version = sys.argv[1:4]
prefix = f"{var} :="
changed = False

with open(makefile, encoding="utf-8") as handle:
    lines = handle.readlines()

with open(makefile, "w", encoding="utf-8") as handle:
    for line in lines:
        if line.startswith(prefix):
            handle.write(f"{prefix} {version}\n")
            changed = True
        else:
            handle.write(line)

if not changed:
    print(f"{var} was not found in {makefile}", file=sys.stderr)
    sys.exit(1)
PY

  echo "Updated $tool ($var) to $version in $MAKEFILE"
}

if [[ -n "$APPLY_TOOL" || -n "$APPLY_VERSION" ]]; then
  if [[ -z "$APPLY_TOOL" || -z "$APPLY_VERSION" ]]; then
    echo "--apply-tool and --version must be used together" >&2
    exit 1
  fi
  apply_tool_update "$APPLY_TOOL" "$APPLY_VERSION"
  exit 0
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required to check for updates" >&2
  exit 1
fi

report_header=$'| Tool | Current | Latest | Status |\n| --- | --- | --- | --- |'
report_rows=()
json_args=()
outdated_count=0

for entry in "${TOOLS[@]}"; do
  IFS="|" read -r slug var pretty repo transform <<<"$entry"

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
  elif [[ "$transform" == "strip_gping_v" ]]; then
    latest_version="${latest_tag#gping-v}"
  fi

  if [[ "$latest_version" == "$current_version" ]]; then
    report_rows+=("| $pretty | $current_version | $latest_version | ✅ up-to-date |")
  else
    report_rows+=("| $pretty | $current_version | $latest_version | 🔁 update available |")
    json_args+=("$slug" "$pretty" "$var" "$repo" "$current_version" "$latest_version")
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

if [[ -n "$JSON_FILE" ]]; then
  python3 - "$JSON_FILE" "${json_args[@]}" <<'PY'
import json
import sys

output_path = sys.argv[1]
fields = sys.argv[2:]
keys = ("tool", "pretty", "var", "repo", "current", "latest")
records = []

if len(fields) % len(keys) != 0:
    print("Invalid update record field count", file=sys.stderr)
    sys.exit(1)

for idx in range(0, len(fields), len(keys)):
    records.append(dict(zip(keys, fields[idx : idx + len(keys)])))

with open(output_path, "w", encoding="utf-8") as handle:
    json.dump(records, handle, indent=2)
    handle.write("\n")
PY
fi

if [[ $outdated_count -gt 0 && $FAIL_ON_OUTDATED -eq 1 ]]; then
  exit 1
fi
