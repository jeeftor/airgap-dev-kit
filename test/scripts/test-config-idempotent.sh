#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$TMP_DIR/package/offline-packages/linux"
mkdir -p "$TMP_DIR/package/config/starship/.config"
mkdir -p "$TMP_DIR/package/config/wezterm/.config/wezterm"
mkdir -p "$TMP_DIR/home"

cp "$ROOT_DIR/install.sh" "$TMP_DIR/package/install.sh"
touch "$TMP_DIR/package/.airgap-cli-only"
cp "$ROOT_DIR/config/starship/.config/starship.toml" "$TMP_DIR/package/config/starship/.config/starship.toml"
cp "$ROOT_DIR/config/wezterm/.config/wezterm/wezterm.lua" "$TMP_DIR/package/config/wezterm/.config/wezterm/wezterm.lua"

for run in 1 2; do
  (
    cd "$TMP_DIR/package"
    PATH="/bin:/usr/bin" HOME="$TMP_DIR/home" OSTYPE=linux-gnu AIRGAP_DEV_KIT_CONFIGURE_SHELLS=0 ./install.sh
  ) > "$TMP_DIR/install-$run.out" 2>&1
done

test -f "$TMP_DIR/home/.config/starship.toml"
test -f "$TMP_DIR/home/.config/wezterm/wezterm.lua"

if compgen -G "$TMP_DIR/home/.config/starship.toml.backup-*" >/dev/null; then
  echo "Repeated identical config install created unnecessary starship backups" >&2
  exit 1
fi

if compgen -G "$TMP_DIR/home/.config/wezterm/wezterm.lua.backup-*" >/dev/null; then
  echo "Repeated identical config install created unnecessary WezTerm backups" >&2
  exit 1
fi

echo "Config idempotency test passed"
