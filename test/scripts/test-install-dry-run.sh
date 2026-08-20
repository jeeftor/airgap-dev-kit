#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$TMP_DIR/package/offline-packages/linux" "$TMP_DIR/package/config"
mkdir -p "$TMP_DIR/home/.config/nvim" "$TMP_DIR/home/.local/share/nvim/lazy"
printf '%s\n' 'user config' > "$TMP_DIR/home/.config/nvim/init.lua"
printf '%s\n' 'user data' > "$TMP_DIR/home/.local/share/nvim/lazy/marker"
printf '%s\n' 'existing transaction' > "$TMP_DIR/home/.airgap-dev-kit-install.log"
cp "$ROOT_DIR/install.sh" "$TMP_DIR/package/install.sh"
chmod +x "$TMP_DIR/package/install.sh"

before=$(find "$TMP_DIR/home" -type f -exec shasum -a 256 {} + | sort)
(
  cd "$TMP_DIR/package"
  PATH="/bin:/usr/bin" HOME="$TMP_DIR/home" OSTYPE=linux-gnu \
    AIRGAP_DEV_KIT_CONFIGURE_SHELLS=0 ./install.sh --dry-run --nvim-mode=replace
) > "$TMP_DIR/dry-run.out" 2>&1
after=$(find "$TMP_DIR/home" -type f -exec shasum -a 256 {} + | sort)

test "$before" = "$after"
grep -q 'DRY RUN PLAN' "$TMP_DIR/dry-run.out"
grep -q 'no files, binaries, configuration, or shell files will be changed' "$TMP_DIR/dry-run.out"

echo "Installer dry-run is side-effect free"
