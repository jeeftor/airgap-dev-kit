#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

MAKEFILE_FIXTURE="$TMP_DIR/Makefile"
RELEASES_DIR="$TMP_DIR/releases"
UPDATES_JSON="$TMP_DIR/updates.json"
mkdir -p "$RELEASES_DIR"

cat > "$MAKEFILE_FIXTURE" <<'EOF'
WEZTERM_VERSION := 20230712-072601-f4abf8fd
FZF_VERSION := 0.66.1
TMUX_VERSION := 3.5a
NVIM_VERSION := v0.11.5
NERD_FONT_VERSION := v3.2.1
BTOP_VERSION := v1.4.7
LSD_VERSION := v1.2.0
ZOX_VERSION := v0.9.9
DELTA_VERSION := 0.19.2
DIFFTASTIC_VERSION := 0.69.0
GUM_VERSION := v0.17.0
DUST_VERSION := v1.2.4
GDU_VERSION := v5.33.0
MKCERT_VERSION := v1.4.4
DIRENV_VERSION := v2.37.1
SVU_VERSION := 3.4.1
GPING_VERSION := 1.20.1
FD_VERSION := 10.2.0
RG_VERSION := 14.1.1
BAT_VERSION := 0.25.0
STARSHIP_VERSION := 1.22.1
EOF

write_release() {
  local repo_key="$1"
  local tag="$2"
  printf '{"tag_name":"%s"}\n' "$tag" > "$RELEASES_DIR/${repo_key}.json"
}

write_release wez__wezterm 20230712-072601-f4abf8fd
write_release junegunn__fzf v0.73.1
write_release nelsonenzo__tmux-appimage 3.5a
write_release neovim__neovim v0.11.5
write_release ryanoasis__nerd-fonts v3.2.1
write_release aristocratos__btop v1.4.7
write_release lsd-rs__lsd v1.2.0
write_release ajeetdsouza__zoxide v0.9.9
write_release dandavison__delta 0.19.2
write_release Wilfred__difftastic 0.69.0
write_release charmbracelet__gum v0.17.0
write_release bootandy__dust v1.2.4
write_release dundee__gdu v5.33.0
write_release FiloSottile__mkcert v1.4.4
write_release direnv__direnv v2.37.1
write_release caarlos0__svu v3.4.1
write_release orf__gping gping-v1.20.1
write_release sharkdp__fd v10.2.0
write_release BurntSushi__ripgrep 14.1.1
write_release sharkdp__bat v0.25.0
write_release starship__starship v1.22.1

AIRGAP_DEV_KIT_RELEASES_DIR="$RELEASES_DIR" \
  bash "$ROOT_DIR/scripts/check-updates.sh" \
  --makefile "$MAKEFILE_FIXTURE" \
  --json-file "$UPDATES_JSON" >/dev/null

python3 - "$UPDATES_JSON" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    updates = json.load(handle)

assert len(updates) == 1, updates
update = updates[0]
assert update["tool"] == "fzf", update
assert update["pretty"] == "fzf", update
assert update["var"] == "FZF_VERSION", update
assert update["current"] == "0.66.1", update
assert update["latest"] == "0.73.1", update
assert update["repo"] == "junegunn/fzf", update
PY

bash "$ROOT_DIR/scripts/check-updates.sh" \
  --makefile "$MAKEFILE_FIXTURE" \
  --apply-tool fzf \
  --version 0.73.1 >/dev/null

if ! grep -q '^FZF_VERSION := 0.73.1$' "$MAKEFILE_FIXTURE"; then
  echo "fzf version was not updated" >&2
  exit 1
fi

if ! grep -q '^BTOP_VERSION := v1.4.7$' "$MAKEFILE_FIXTURE"; then
  echo "unrelated version changed" >&2
  exit 1
fi

echo "check-updates JSON and single-tool apply tests passed"
