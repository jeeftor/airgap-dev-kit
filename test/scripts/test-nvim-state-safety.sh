#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

rg -q 'Y\) Back up the complete Neovim state and install this kit' "$ROOT_DIR/install.sh"
rg -q 'n\) Preserve the existing Neovim state and skip this kit' "$ROOT_DIR/install.sh"
rg -q 'Choose how to handle your existing Neovim setup:' "$ROOT_DIR/install.sh"

mkdir -p "$TMP_DIR/package/offline-packages/linux"
mkdir -p "$TMP_DIR/package/config"
mkdir -p "$TMP_DIR/home/.config/nvim/lua/plugins"
mkdir -p "$TMP_DIR/home/.local/share/nvim/lazy/old-plugin"
mkdir -p "$TMP_DIR/home/.local/state/nvim" "$TMP_DIR/home/.cache/nvim"

cp "$ROOT_DIR/install.sh" "$TMP_DIR/package/install.sh"
cp -R "$ROOT_DIR/config/nvim" "$TMP_DIR/package/config/"

printf '%s\n' 'return { { "old/plugin" } }' > "$TMP_DIR/home/.config/nvim/lua/plugins/old.lua"
printf '%s\n' 'old data' > "$TMP_DIR/home/.local/share/nvim/lazy/old-plugin/marker"
printf '%s\n' 'old state' > "$TMP_DIR/home/.local/state/nvim/marker"
printf '%s\n' 'old cache' > "$TMP_DIR/home/.cache/nvim/marker"

mkdir -p "$TMP_DIR/lazy/lazy/lazy.nvim"
printf '%s\n' 'bundled plugin' > "$TMP_DIR/lazy/lazy/lazy.nvim/README"
printf '%s\n' '{}' > "$TMP_DIR/lazy/lazy-lock.json"
tar -czf "$TMP_DIR/package/offline-packages/lazy-plugins.tar.gz" -C "$TMP_DIR/lazy" lazy lazy-lock.json

mkdir -p "$TMP_DIR/mason/mason/bin"
mkdir -p "$TMP_DIR/mason/mason/packages/gopls"
mkdir -p "$TMP_DIR/mason/mason/node/bin"
printf '%s\n' '#!/usr/bin/env sh' 'exit 0' > "$TMP_DIR/mason/mason/bin/gopls"
printf '%s\n' '#!/usr/bin/env sh' 'exit 0' > "$TMP_DIR/mason/mason/node/bin/node"
chmod +x "$TMP_DIR/mason/mason/bin/gopls" "$TMP_DIR/mason/mason/node/bin/node"
tar -czf "$TMP_DIR/package/offline-packages/mason-lsp.tar.gz" -C "$TMP_DIR/mason" mason

(
  cd "$TMP_DIR/package"
  PATH="/bin:/usr/bin" HOME="$TMP_DIR/home" OSTYPE=linux-gnu \
    AIRGAP_DEV_KIT_CONFIGURE_SHELLS=0 ./install.sh --nvim-mode=replace
) > "$TMP_DIR/install.out" 2>&1

test -f "$TMP_DIR/home/.config/nvim/init.lua"
test ! -e "$TMP_DIR/home/.config/nvim/lua/plugins/old.lua"
test -f "$TMP_DIR/home/.local/share/nvim/lazy/lazy.nvim/README"
test -f "$TMP_DIR/home/.local/share/nvim/lazy-lock.json"
test ! -e "$TMP_DIR/home/.local/share/nvim/lazy/old-plugin"
test -x "$TMP_DIR/home/.local/share/nvim/mason/bin/gopls"
test -x "$TMP_DIR/home/.local/share/nvim/mason/node/bin/node"

backup_root=$(find "$TMP_DIR/home/.local/share/airgap-dev-kit/backups" -maxdepth 1 -mindepth 1 -type d | head -1)
test -n "$backup_root"
test -f "$backup_root/.config/nvim/lua/plugins/old.lua"
test -f "$backup_root/.local/share/nvim/lazy/old-plugin/marker"
test -f "$backup_root/.local/state/nvim/marker"
test -f "$backup_root/.cache/nvim/marker"

mkdir -p "$TMP_DIR/preserve-home/.config/nvim"
printf '%s\n' 'preserve me' > "$TMP_DIR/preserve-home/.config/nvim/init.lua"
printf '%s\n' 'METADATA|KIT_VERSION=0.9.0||' > "$TMP_DIR/preserve-home/.airgap-dev-kit-install.log"
(
  cd "$TMP_DIR/package"
  PATH="/bin:/usr/bin" HOME="$TMP_DIR/preserve-home" OSTYPE=linux-gnu \
    AIRGAP_DEV_KIT_CONFIGURE_SHELLS=0 ./install.sh
) > "$TMP_DIR/preserve.out" 2>&1

rg -q 'preserving it and skipping kit Neovim setup' "$TMP_DIR/preserve.out"
grep -q 'preserve me' "$TMP_DIR/preserve-home/.config/nvim/init.lua"
test ! -e "$TMP_DIR/preserve-home/.local/share/nvim/lazy"
rg -q 'Detected a previous Air-Gap Dev Kit installation \(version: 0.9.0\)' "$TMP_DIR/preserve.out"

echo "Neovim state backup and atomic payload installation test passed"
