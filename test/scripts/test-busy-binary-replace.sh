#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "Skipping busy binary replacement test on non-Linux host"
  exit 0
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_DIR="$(mktemp -d)"
RUNNING_PID=""
trap '[[ -n "$RUNNING_PID" ]] && kill "$RUNNING_PID" 2>/dev/null || true; rm -rf "$TMP_DIR"' EXIT

if [[ $EUID -eq 0 ]]; then
  TARGET_BIN_DIR="/usr/local/bin"
else
  TARGET_BIN_DIR="$TMP_DIR/home/.local/bin"
fi

mkdir -p "$TMP_DIR/package/offline-packages/linux" "$TMP_DIR/home/.local/bin" "$TARGET_BIN_DIR"

cp "$ROOT_DIR/install.sh" "$TMP_DIR/package/install.sh"
touch "$TMP_DIR/package/.airgap-cli-only"

# Use real ELF binaries so Linux exercises ETXTBSY behavior for running files.
cp /bin/bash "$TMP_DIR/package/offline-packages/linux/btop"
cp /bin/sleep "$TARGET_BIN_DIR/btop"

"$TARGET_BIN_DIR/btop" 30 &
RUNNING_PID="$!"
sleep 0.2

(
  cd "$TMP_DIR/package"
  HOME="$TMP_DIR/home" OSTYPE=linux-gnu ./install.sh
) > "$TMP_DIR/install.out" 2>&1

grep -q "btop installed" "$TMP_DIR/install.out"
"$TARGET_BIN_DIR/btop" --version | grep -q "GNU bash"

echo "Busy binary replacement test passed"
