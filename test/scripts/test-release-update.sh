#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$TMP_DIR/api/repos/example/kit" "$TMP_DIR/out"
printf '%s\n' 'verified release payload' > "$TMP_DIR/airgap-dev-kit-linux-x86_64.tar.gz"
checksum=$(shasum -a 256 "$TMP_DIR/airgap-dev-kit-linux-x86_64.tar.gz" | awk '{print $1}')
printf '%s  %s\n' "$checksum" 'airgap-dev-kit-linux-x86_64.tar.gz' > "$TMP_DIR/checksums.txt"

cat > "$TMP_DIR/api/repos/example/kit/releases" <<EOF
[{"tag_name":"v9.9.9","assets":[
  {"name":"airgap-dev-kit-linux-x86_64.tar.gz","browser_download_url":"file://$TMP_DIR/airgap-dev-kit-linux-x86_64.tar.gz"},
  {"name":"checksums.txt","browser_download_url":"file://$TMP_DIR/checksums.txt"}
]}]
EOF

AIRGAP_DEV_KIT_API_URL="file://$TMP_DIR/api" AIRGAP_DEV_KIT_REPO=example/kit \
  "$ROOT_DIR/scripts/release-update.sh" download --dir "$TMP_DIR/out" > "$TMP_DIR/download.out"
test -f "$TMP_DIR/out/airgap-dev-kit-linux-x86_64.tar.gz"
test "$(shasum -a 256 "$TMP_DIR/out/airgap-dev-kit-linux-x86_64.tar.gz" | awk '{print $1}')" = "$checksum"
grep -q 'Download verified' "$TMP_DIR/download.out"

mkdir -p "$TMP_DIR/kit/airgap-dev-kit"
cat > "$TMP_DIR/kit/airgap-dev-kit/airgap" <<'EOF'
#!/usr/bin/env sh
test "$1" = install
test "$2" = --yes
printf '%s\n' "$3" > "${AIRGAP_TEST_RESULT:?}"
EOF
chmod +x "$TMP_DIR/kit/airgap-dev-kit/airgap"
printf '%s\n' '{"schema_version":1}' > "$TMP_DIR/kit/airgap-dev-kit/kit-manifest.json"
tar -czf "$TMP_DIR/apply-kit.tar.gz" -C "$TMP_DIR/kit" airgap-dev-kit
apply_checksum=$(shasum -a 256 "$TMP_DIR/apply-kit.tar.gz" | awk '{print $1}')
printf '%s  %s\n' "$apply_checksum" apply-kit.tar.gz > "$TMP_DIR/apply-checksums.txt"
AIRGAP_TEST_RESULT="$TMP_DIR/apply-result" \
  XDG_DATA_HOME="$TMP_DIR/data" \
  "$ROOT_DIR/scripts/release-update.sh" apply --archive "$TMP_DIR/apply-kit.tar.gz" --checksums "$TMP_DIR/apply-checksums.txt" -- --yes --configure-shell=false
test "$(cat "$TMP_DIR/apply-result")" = --configure-shell=false

sed -i.bak 's/"tag_name":"v9.9.9"/"tag_name":"build-176"/' "$TMP_DIR/api/repos/example/kit/releases"
if AIRGAP_DEV_KIT_API_URL="file://$TMP_DIR/api" AIRGAP_DEV_KIT_REPO=example/kit \
  "$ROOT_DIR/scripts/release-update.sh" download --dir "$TMP_DIR/out"; then
  echo "legacy build tag unexpectedly succeeded" >&2
  exit 1
fi
sed -i.bak 's/"tag_name":"build-176"/"tag_name":"v9.9.9"/' "$TMP_DIR/api/repos/example/kit/releases"

printf '%064d  %s\n' 0 'airgap-dev-kit-linux-x86_64.tar.gz' > "$TMP_DIR/checksums.txt"
rm -f "$TMP_DIR/out/airgap-dev-kit-linux-x86_64.tar.gz" "$TMP_DIR/out/checksums.txt"
if AIRGAP_DEV_KIT_API_URL="file://$TMP_DIR/api" AIRGAP_DEV_KIT_REPO=example/kit \
  "$ROOT_DIR/scripts/release-update.sh" download --dir "$TMP_DIR/out"; then
  echo "checksum mismatch unexpectedly succeeded" >&2
  exit 1
fi
test ! -e "$TMP_DIR/out/airgap-dev-kit-linux-x86_64.tar.gz"

echo "Verified release download test passed"
