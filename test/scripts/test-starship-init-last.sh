#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$TMP_DIR/package/offline-packages/linux" "$TMP_DIR/home/.local/bin" "$TMP_DIR/home"

cp "$ROOT_DIR/install.sh" "$TMP_DIR/package/install.sh"
touch "$TMP_DIR/package/.airgap-cli-only"
cp /bin/sh "$TMP_DIR/package/offline-packages/linux/starship"

cat > "$TMP_DIR/home/.bashrc" <<'EOF'
eval "$(starship init bash)"
PS1='legacy % '
EOF

(
  cd "$TMP_DIR/package"
  PATH="/bin:/usr/bin" HOME="$TMP_DIR/home" OSTYPE=linux-gnu AIRGAP_DEV_KIT_CONFIGURE_SHELLS=1 ./install.sh
) > "$TMP_DIR/install.out" 2>&1

# shellcheck disable=SC2016
tail -n 1 "$TMP_DIR/home/.bashrc" | grep -F 'eval "$(starship init bash)"'

echo "Starship terminal init test passed"
