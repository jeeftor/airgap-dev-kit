#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/../.." && pwd)
tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/airgap-v2-package-test.XXXXXX")
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM

fixture="$tmp_dir/fixture"
mkdir -p "$fixture/offline-packages/linux" "$fixture/config" "$fixture/scripts" "$fixture/docs"
cp "$repo_root/scripts/package-v2.sh" "$fixture/scripts/"
cp "$repo_root/README.md" "$fixture/"
printf '%s\n' '#!/bin/sh' 'exit 0' > "$fixture/offline-packages/linux/example-tool"
printf '%s\n' '#!/bin/sh' 'echo airgap' > "$fixture/airgap"
printf '%s\n' 'lazy payload' > "$fixture/offline-packages/lazy-plugins.tar.gz"
printf '%s\n' 'mason payload' > "$fixture/offline-packages/mason-lsp.tar.gz"
chmod +x "$fixture/airgap" "$fixture/offline-packages/linux/example-tool"

(
  cd "$fixture"
  sh scripts/package-v2.sh --binary ./airgap --version v0.0.0 --output "$tmp_dir/output"
)

archive="$tmp_dir/output/airgap-dev-kit-linux-x86_64.tar.gz"
test -f "$archive"
tar -tzf "$archive" | grep -Fx 'airgap-dev-kit/airgap'
tar -tzf "$archive" | grep -Fx 'airgap-dev-kit/offline-packages/linux/amd64/airgap'
tar -tzf "$archive" | grep -Fx 'airgap-dev-kit/offline-packages/lazy-plugins.tar.gz'
tar -tzf "$archive" | grep -Fx 'airgap-dev-kit/offline-packages/mason-lsp.tar.gz'
tar -tvzf "$archive" | grep -F 'airgap-dev-kit/airgap -> offline-packages/linux/airgap'
if tar -tzf "$archive" | grep -Eq '^airgap-dev-kit/(install|uninstall)\.sh$|^airgap-dev-kit/scripts/'; then
  echo 'v2 package must not ship legacy lifecycle scripts' >&2
  exit 1
fi

assert_missing_payload_is_rejected() {
  payload_name=$1
  case_dir="$tmp_dir/missing-${payload_name%.tar.gz}"
  cp -R "$fixture" "$case_dir"
  rm -f "$case_dir/offline-packages/$payload_name"

  if (
    cd "$case_dir"
    sh scripts/package-v2.sh --binary ./airgap --version v0.0.0 --output "$tmp_dir/output-missing-${payload_name%.tar.gz}"
  ); then
    echo "v2 package must reject a missing offline-packages/$payload_name payload" >&2
    exit 1
  fi
}

# A successful package must be self-contained: both archives are needed to
# install LazyVim and Mason without reaching the network on the target host.
assert_missing_payload_is_rejected lazy-plugins.tar.gz
assert_missing_payload_is_rejected mason-lsp.tar.gz

echo 'v2 package layout verified'
