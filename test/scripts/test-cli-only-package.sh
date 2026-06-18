#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

cd "$ROOT_DIR"

make --no-print-directory package-cli >/tmp/airgap-package-cli.out

test -f airgap-dev-kit-cli.tar.gz
tar -tzf airgap-dev-kit-cli.tar.gz > "$TMP_DIR/package-files.txt"

grep -q '^airgap-dev-kit/install.sh$' "$TMP_DIR/package-files.txt"
grep -q '^airgap-dev-kit/\.airgap-cli-only$' "$TMP_DIR/package-files.txt"
grep -q '^airgap-dev-kit/offline-packages/linux/tmux-3.4-static-x86_64$' "$TMP_DIR/package-files.txt"

if grep -q '^airgap-dev-kit/offline-packages/linux/wezterm.AppImage$' "$TMP_DIR/package-files.txt"; then
  echo "CLI-only package must not include WezTerm" >&2
  exit 1
fi

if grep -q '^airgap-dev-kit/fonts/' "$TMP_DIR/package-files.txt"; then
  echo "CLI-only package must not include fonts" >&2
  exit 1
fi

mkdir "$TMP_DIR/extract"
tar -xzf airgap-dev-kit-cli.tar.gz -C "$TMP_DIR/extract"
test -d "$TMP_DIR/extract/airgap-dev-kit"
mkdir -p "$TMP_DIR/home"

(
  cd "$TMP_DIR/extract/airgap-dev-kit"
  HOME="$TMP_DIR/home" bash -c 'OSTYPE=linux-gnu; source ./install.sh --dry-run'
) > "$TMP_DIR/install.out" 2>&1

grep -q "CLI-only mode" "$TMP_DIR/install.out"

if grep -q "Install WezTerm" "$TMP_DIR/install.out"; then
  echo "CLI-only installer must not prompt for WezTerm" >&2
  exit 1
fi

if grep -q "Font Installation Info" "$TMP_DIR/install.out"; then
  echo "CLI-only installer must not show font installation prompts" >&2
  exit 1
fi

echo "CLI-only package tests passed"
