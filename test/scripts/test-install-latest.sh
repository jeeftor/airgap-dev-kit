#!/usr/bin/env bash
# Verify that the release bootstrap installs only the tag it shipped with.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

TAG="v9.9.9"
ASSET="airgap-dev-kit-linux-x86_64.tar.gz"
API_DIR="$TMP_DIR/api/repos/example/kit/releases/tags"
KIT_DIR="$TMP_DIR/kit/airgap-dev-kit"
BIN_DIR="$TMP_DIR/bin"
mkdir -p "$API_DIR" "$KIT_DIR" "$BIN_DIR"

cat > "$BIN_DIR/uname" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  -s) echo Linux ;;
  -m) echo x86_64 ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$BIN_DIR/uname"

cat > "$KIT_DIR/airgap" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  doctor) test "${2:-}" = "--verify" ;;
  install) test "${2:-}" = "--yes"; printf '%s\n' "${3:-}" > "${AIRGAP_TEST_RESULT:?}" ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$KIT_DIR/airgap"
tar -czf "$TMP_DIR/$ASSET" -C "$TMP_DIR/kit" airgap-dev-kit
CHECKSUM="$(sha256sum "$TMP_DIR/$ASSET" | awk '{print $1}')"
printf '%s  %s\n' "$CHECKSUM" "$ASSET" > "$TMP_DIR/checksums.txt"
cat > "$API_DIR/$TAG" <<EOF
{"tag_name":"$TAG","assets":[
  {"name":"$ASSET","browser_download_url":"file://$TMP_DIR/$ASSET"},
  {"name":"checksums.txt","browser_download_url":"file://$TMP_DIR/checksums.txt"}
]}
EOF

AIRGAP_TEST_RESULT="$TMP_DIR/result" \
AIRGAP_DEV_KIT_API_URL="file://$TMP_DIR/api" \
AIRGAP_DEV_KIT_REPO=example/kit \
AIRGAP_DEV_KIT_VERSION="$TAG" \
PATH="$BIN_DIR:$PATH" \
  bash "$ROOT_DIR/scripts/install-latest.sh" --test-option
test "$(cat "$TMP_DIR/result")" = "--test-option"

if AIRGAP_DEV_KIT_API_URL="file://$TMP_DIR/api" AIRGAP_DEV_KIT_REPO=example/kit \
  AIRGAP_DEV_KIT_VERSION=v9.9.8 PATH="$BIN_DIR:$PATH" bash "$ROOT_DIR/scripts/install-latest.sh"; then
  echo "bootstrap accepted a release tag without metadata" >&2
  exit 1
fi

echo "Verified release-bound bootstrap installer"
