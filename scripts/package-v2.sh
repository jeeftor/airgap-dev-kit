#!/bin/sh
# Build a target-explicit v2 kit from a prebuilt static airgap binary.
set -eu

binary=
flavor=full
output=.
version=$(sed -n '1p' VERSION 2>/dev/null || printf '%s' dev)

usage() { echo "Usage: $0 --binary PATH [--flavor full|cli] [--output DIR] [--version VERSION]" >&2; exit 2; }
while [ "$#" -gt 0 ]; do
  case "$1" in
    --binary) binary=$2; shift 2 ;;
    --flavor) flavor=$2; shift 2 ;;
    --output) output=$2; shift 2 ;;
    --version) version=$2; shift 2 ;;
    *) usage ;;
  esac
done
[ -x "$binary" ] || { echo "A built executable is required: $binary" >&2; exit 1; }
[ "$flavor" = full ] || [ "$flavor" = cli ] || usage

name="airgap-dev-kit"
archive="airgap-dev-kit-linux-x86_64.tar.gz"
[ "$flavor" = cli ] && archive="airgap-dev-kit-cli-linux-x86_64.tar.gz"
stage=$(mktemp -d "${TMPDIR:-/tmp}/airgap-v2.XXXXXX")
trap 'rm -rf "$stage"' EXIT HUP INT TERM
root="$stage/$name"
mkdir -p "$root/offline-packages/linux/amd64"
cp install.sh uninstall.sh README.md "$root/"
printf '%s\n' "$version" > "$root/VERSION"
cp -R config scripts docs "$root/"
cp -R offline-packages/linux/. "$root/offline-packages/linux/amd64/"
for payload_archive in lazy-plugins.tar.gz mason-lsp.tar.gz; do
  if [ -f "offline-packages/$payload_archive" ]; then
    cp "offline-packages/$payload_archive" "$root/offline-packages/"
  fi
done
cp "$binary" "$root/offline-packages/linux/amd64/airgap"
rm -f "$root/offline-packages/linux/amd64/airgap-dev-kit"
ln -s airgap "$root/offline-packages/linux/amd64/airgap-dev-kit"
# Keep the package immediately usable after extraction. The canonical payload
# remains target-specific, while these launchers avoid requiring a PATH change.
ln -s offline-packages/linux/airgap "$root/airgap"
ln -s airgap "$root/airgap-dev-kit"
# Keep the proven v1 installer usable while v2 migrates lifecycle operations:
# root entries are lightweight links, while the manifest selects amd64.
for entry in "$root/offline-packages/linux/amd64"/*; do
  base=$(basename "$entry")
  ln -s "amd64/$base" "$root/offline-packages/linux/$base"
done
if [ "$flavor" = cli ]; then
  touch "$root/.airgap-cli-only"
  rm -f "$root/offline-packages/linux/amd64/wezterm.AppImage"
else
  [ -d fonts ] && cp -R fonts "$root/"
fi
sha256() { sha256sum "$1" 2>/dev/null | awk '{print $1}' || shasum -a 256 "$1" | awk '{print $1}'; }
payload_digest=$(find "$root/offline-packages/linux/amd64" -type f -print | LC_ALL=C sort | while IFS= read -r file; do sha256 "$file"; done | sha256sum 2>/dev/null | awk '{print $1}' || true)
cat > "$root/kit-manifest.json" <<EOF
{"schema_version":1,"version":"$version","target":"linux/amd64","flavor":"$flavor","payload_dir":"offline-packages/linux/amd64","payload_digest":"$payload_digest"}
EOF
mkdir -p "$output"
COPYFILE_DISABLE=1 tar --no-xattrs -czf "$output/$archive" -C "$stage" "$name"
printf '%s  %s\n' "$(sha256 "$output/$archive")" "$archive" > "$output/checksums.txt"
echo "Created $output/$archive"
