#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$TMP_DIR/api/repos/example/kit/releases" "$TMP_DIR/out"
printf '%s\n' 'verified release payload' > "$TMP_DIR/airgap-dev-kit-linux-x86_64.tar.gz"
checksum=$(shasum -a 256 "$TMP_DIR/airgap-dev-kit-linux-x86_64.tar.gz" | awk '{print $1}')
printf '%s  %s\n' "$checksum" 'airgap-dev-kit-linux-x86_64.tar.gz' > "$TMP_DIR/checksums.txt"

cat > "$TMP_DIR/api/repos/example/kit/releases/latest" <<EOF
{"tag_name":"v9.9.9","assets":[
  {"name":"airgap-dev-kit-linux-x86_64.tar.gz","browser_download_url":"file://$TMP_DIR/airgap-dev-kit-linux-x86_64.tar.gz"},
  {"name":"checksums.txt","browser_download_url":"file://$TMP_DIR/checksums.txt"}
]}
EOF

AIRGAP_DEV_KIT_API_URL="file://$TMP_DIR/api" AIRGAP_DEV_KIT_REPO=example/kit \
  "$ROOT_DIR/scripts/release-update.sh" download --dir "$TMP_DIR/out" > "$TMP_DIR/download.out"
test -f "$TMP_DIR/out/airgap-dev-kit-linux-x86_64.tar.gz"
test "$(shasum -a 256 "$TMP_DIR/out/airgap-dev-kit-linux-x86_64.tar.gz" | awk '{print $1}')" = "$checksum"
grep -q 'Download verified' "$TMP_DIR/download.out"

sed -i.bak 's/"tag_name":"v9.9.9"/"tag_name":"build-176"/' "$TMP_DIR/api/repos/example/kit/releases/latest"
if AIRGAP_DEV_KIT_API_URL="file://$TMP_DIR/api" AIRGAP_DEV_KIT_REPO=example/kit \
  "$ROOT_DIR/scripts/release-update.sh" download --dir "$TMP_DIR/out"; then
  echo "legacy build tag unexpectedly succeeded" >&2
  exit 1
fi
sed -i.bak 's/"tag_name":"build-176"/"tag_name":"v9.9.9"/' "$TMP_DIR/api/repos/example/kit/releases/latest"

printf '%064d  %s\n' 0 'airgap-dev-kit-linux-x86_64.tar.gz' > "$TMP_DIR/checksums.txt"
rm -f "$TMP_DIR/out/airgap-dev-kit-linux-x86_64.tar.gz" "$TMP_DIR/out/checksums.txt"
if AIRGAP_DEV_KIT_API_URL="file://$TMP_DIR/api" AIRGAP_DEV_KIT_REPO=example/kit \
  "$ROOT_DIR/scripts/release-update.sh" download --dir "$TMP_DIR/out"; then
  echo "checksum mismatch unexpectedly succeeded" >&2
  exit 1
fi
test ! -e "$TMP_DIR/out/airgap-dev-kit-linux-x86_64.tar.gz"

echo "Verified release download test passed"
