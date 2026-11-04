#!/usr/bin/env bash
set -euo pipefail

updater=$(realpath "${1:?Pass the Linux airgap executable under test}")
releases=$(realpath "${2:?Pass the directory containing signed v2.7.0 and v2.7.1 releases}")
results=${AIRGAP_UPGRADE_RESULTS:-/tmp/airgap-upgrade-results}
mkdir -p "$results"
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/airgap-upgrade.XXXXXX")
trap 'rm -rf "$work_dir"' EXIT
test "$(id -u)" -ne 0

# Both archives must be authentic published releases; no PR-only signing key.
for version in v2.7.0 v2.7.1; do
  "$updater" update apply --from "$releases/$version" --dry-run
done

export HOME="$work_dir/home"
export XDG_CONFIG_HOME="$HOME/.config" XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state" XDG_CACHE_HOME="$HOME/.cache"
export PATH="$HOME/.local/bin:$PATH" SHELL=/bin/bash
unset AIRGAP_KIT_DIR NVIM_APPNAME VIMINIT EXINIT
mkdir -p "$HOME/.config/nvim" "$HOME/.config/wezterm" "$HOME/.config/kitty" \
  "$HOME/.config/ghostty" "$XDG_DATA_HOME/nvim/personal" "$HOME/.local/bin" "$HOME/projects"
printf '%s\n' 'vim.g.personal_profile = true' > "$HOME/.config/nvim/init.lua"
printf '%s\n' 'return {font_size = 13}' > "$HOME/.config/wezterm/wezterm.lua"
printf '%s\n' 'font_size 13' > "$HOME/.config/kitty/kitty.conf"
printf '%s\n' 'font-size = 13' > "$HOME/.config/ghostty/config"
printf '%s\n' 'personal editor data' > "$XDG_DATA_HOME/nvim/personal/sentinel"
printf '%s\n' '#!/bin/sh' 'printf "personal tool\n"' > "$HOME/.local/bin/personal-tool"
chmod +x "$HOME/.local/bin/personal-tool"
printf '%s\n' 'personal project content' > "$HOME/projects/sentinel"
printf '%s\n' '# Personal shell configuration' 'export PERSONAL_SETTING=kept' > "$HOME/.bashrc"
cd "$HOME"
find .config/nvim .config/wezterm .config/kitty .config/ghostty \
  .local/share/nvim/personal .local/bin/personal-tool projects -type f -exec sha256sum {} + \
  > "$results/personal-files.sha256"

verify_personal_files() {
  sha256sum --check "$results/personal-files.sha256"
  rg -q '^export PERSONAL_SETTING=kept$' "$HOME/.bashrc"
  test "$(personal-tool)" = 'personal tool'
}

verify_installation() {
  local version=$1
  airgap version | tee "$results/installed-$version.txt" | rg -F "airgap $version ("
  "$updater" doctor --verify > "$results/doctor-$version.txt"
  verify_personal_files
  test "$(rg -c '^# >>> airgap dev kit >>>$' "$HOME/.bashrc")" = 1
  bash --noprofile --rcfile "$HOME/.bashrc" -ic \
    'test "$PERSONAL_SETTING" = kept; command -v starship' \
    > "$results/shell-$version.txt" 2>&1
}

"$updater" update apply --from "$releases/v2.7.0" --yes > "$results/apply-v2.7.0.txt" 2>&1
# Begin the upgrade with shell integration explicitly enabled, as after install.
airgap install --yes --nvim-mode=preserve --configure-shell=true \
  > "$results/configure-v2.7.0.txt" 2>&1
verify_installation v2.7.0
"$updater" update apply --from "$releases/v2.7.1" --yes > "$results/apply-v2.7.1.txt" 2>&1
verify_installation v2.7.1
"$updater" update rollback --yes > "$results/rollback.txt" 2>&1
verify_installation v2.7.0
"$updater" uninstall --yes > "$results/uninstall.txt" 2>&1
verify_personal_files
if rg -q '^# >>> airgap dev kit >>>$' "$HOME/.bashrc"; then
  echo 'Uninstall left its shell integration behind' >&2
  exit 1
fi
test ! -e "$HOME/.local/bin/airgap"
test ! -e "$HOME/.local/bin/nvim"
echo 'PASS signed v2.7.0 -> v2.7.1 upgrade, rollback, shell integration, and personal-file preservation' \
  | tee "$results/result.txt"
