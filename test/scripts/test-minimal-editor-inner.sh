#!/usr/bin/env bash
set -euo pipefail

test "$(id -u)" -ne 0
for tool in node npm python python3 go rustc cargo gcc cc curl wget; do
  if command -v "$tool" >/dev/null 2>&1; then
    echo "Unexpected host tool in minimal image: $tool" >&2
    exit 1
  fi
done
# Dormant tunnel devices can exist even in Docker's network-none namespace.
test -z "$(awk 'NR > 1 && $1 != "lo" { print }' /proc/net/route)"
git --version
bash /work/test/scripts/test-editor-health.sh /work/kit.tar.gz
