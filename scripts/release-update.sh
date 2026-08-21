#!/usr/bin/env bash
# Verified GitHub release update helper for Air-Gap Dev Kit.
set -euo pipefail

REPO="${AIRGAP_DEV_KIT_REPO:-jeeftor/airgap-dev-kit}"
API_URL="${AIRGAP_DEV_KIT_API_URL:-https://api.github.com}"
DOWNLOAD_DIR="${AIRGAP_DEV_KIT_DOWNLOAD_DIR:-$PWD}"
ASSET="airgap-dev-kit-linux-x86_64.tar.gz"

usage() {
  cat <<'EOF'
Usage: release-update.sh <check|download|apply> [options]

Commands:
  check                         Compare the installed kit with the latest release.
  download [--dir DIR]          Download and checksum-verify the Linux package.
  apply --archive FILE --checksums FILE [-- <install.sh options>]
                                Verify, safely extract, and run that release's installer.

Environment:
  AIRGAP_DEV_KIT_REPO           GitHub repository (default: jeeftor/airgap-dev-kit)
  AIRGAP_DEV_KIT_API_URL        GitHub API base URL (test override)
EOF
}

die() { echo "Error: $*" >&2; exit 1; }

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}';
  else shasum -a 256 "$1" | awk '{print $1}'; fi
}

release_json() {
  curl -fsSL "$API_URL/repos/$REPO/releases" | python3 -c '
import json, re, sys

semver = re.compile(r"^v?[0-9]+\.[0-9]+\.[0-9]+(?:[-.][0-9A-Za-z.]+)?$")
for release in json.load(sys.stdin):
    assets = {asset.get("name") for asset in release.get("assets", [])}
    if (
        not release.get("draft")
        and semver.match(release.get("tag_name", ""))
        and {"airgap-dev-kit-linux-x86_64.tar.gz", "checksums.txt"} <= assets
    ):
        print(json.dumps(release))
        break
else:
    raise SystemExit(1)
'
}

release_fields() {
  python3 -c '
import json, sys
r = json.load(sys.stdin)
assets = {a["name"]: a["browser_download_url"] for a in r.get("assets", [])}
for name in ("tag_name", "airgap-dev-kit-linux-x86_64.tar.gz", "checksums.txt"):
    print(r.get(name, "") if name == "tag_name" else assets.get(name, ""))
'
}

installed_version() {
  local root="${AIRGAP_DEV_KIT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
  [[ -f "$root/VERSION" ]] && head -n 1 "$root/VERSION" || echo "unknown"
}

require_semver_tag() {
  local tag="$1"
  [[ "$tag" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+([-.][0-9A-Za-z.]+)?$ ]] || die "Latest GitHub release is $tag, not a SemVer v2 release. Publish a vX.Y.Z release before downloading."
}

command_check() {
  local latest current release
  release=$(release_json) || die "No published SemVer release with the Linux kit and checksums was found"
  latest=$(printf '%s\n' "$release" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("tag_name", "unknown"))')
  require_semver_tag "$latest"
  current=$(installed_version)
  echo "Installed: $current"
  echo "Latest:    $latest"
  [[ "$current" == "$latest" ]] && echo "✓ Air-Gap Dev Kit is current" || echo "Update available: $latest"
}

command_download() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dir) DOWNLOAD_DIR="$2"; shift 2 ;;
      --asset) ASSET="$2"; shift 2 ;;
      *) die "Unknown download option: $1" ;;
    esac
  done
  command -v curl >/dev/null 2>&1 || die "curl is required"
  command -v python3 >/dev/null 2>&1 || die "python3 is required"
  local fields tag asset_url checksums_url temp_dir expected actual release
  release=$(release_json) || die "No published SemVer release with the Linux kit and checksums was found"
  fields=$(printf '%s\n' "$release" | release_fields)
  tag=$(printf '%s\n' "$fields" | sed -n '1p')
  asset_url=$(printf '%s\n' "$fields" | sed -n '2p')
  checksums_url=$(printf '%s\n' "$fields" | sed -n '3p')
  [[ -n "$tag" && -n "$asset_url" && -n "$checksums_url" ]] || die "Release does not publish $ASSET and checksums.txt"
  require_semver_tag "$tag"
  mkdir -p "$DOWNLOAD_DIR"
  temp_dir=$(mktemp -d "$DOWNLOAD_DIR/.airgap-release.XXXXXX")
  trap 'rm -rf "$temp_dir"' RETURN
  echo "Downloading $ASSET from $tag..."
  curl -fL --retry 4 -o "$temp_dir/$ASSET" "$asset_url"
  curl -fL --retry 4 -o "$temp_dir/checksums.txt" "$checksums_url"
  expected=$(awk -v file="$ASSET" '$2 == file { print $1 }' "$temp_dir/checksums.txt")
  [[ "$expected" =~ ^[[:xdigit:]]{64}$ ]] || die "No valid SHA-256 entry for $ASSET"
  actual=$(sha256_file "$temp_dir/$ASSET")
  [[ "$actual" == "$expected" ]] || die "Checksum mismatch for $ASSET"
  mv -f "$temp_dir/$ASSET" "$DOWNLOAD_DIR/$ASSET"
  mv -f "$temp_dir/checksums.txt" "$DOWNLOAD_DIR/checksums.txt"
  trap - RETURN
  rmdir "$temp_dir"
  echo "✓ Download verified: $DOWNLOAD_DIR/$ASSET"
  echo "  Release: $tag"
}

command_apply() {
  local archive="" checksums=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --archive) archive="$2"; shift 2 ;;
      --checksums) checksums="$2"; shift 2 ;;
      --) shift; break ;;
      *) die "Unknown apply option: $1" ;;
    esac
  done
  [[ -f "$archive" && -f "$checksums" ]] || die "--archive and --checksums must name readable files"
  local name expected actual stage top kit_root kit_store kit_id
  name=$(basename "$archive")
  expected=$(awk -v file="$name" '$2 == file { print $1 }' "$checksums")
  [[ "$expected" =~ ^[[:xdigit:]]{64}$ ]] || die "No valid SHA-256 entry for $name"
  actual=$(sha256_file "$archive")
  [[ "$actual" == "$expected" ]] || die "Checksum mismatch for $name"
  tar -tzf "$archive" | awk 'BEGIN { valid=1 } /^\/|(^|\/)\.\.($|\/)/ { valid=0 } END { exit !valid }' || die "Archive contains unsafe paths"
  kit_store="${XDG_DATA_HOME:-$HOME/.local/share}/airgap-dev-kit/kits"
  mkdir -p "$kit_store"
  stage=$(mktemp -d "$kit_store/.stage.XXXXXX")
  trap 'rm -rf "$stage"' RETURN
  tar -xzf "$archive" -C "$stage"
  top=$(find "$stage" -mindepth 1 -maxdepth 1 -type d -print -quit)
  [[ -n "$top" && -f "$top/install.sh" ]] || die "Archive does not contain an Air-Gap Dev Kit root"
  kit_id="$(basename "$archive" .tar.gz)-$(date +%Y%m%d-%H%M%S)"
  kit_root="$kit_store/$kit_id"
  mv "$top" "$kit_root"
  trap - RETURN
  rmdir "$stage"
  echo "✓ Verified release extracted to $kit_root"
  (cd "$kit_root" && ./install.sh "$@")
}

case "${1:-}" in
  check) shift; [[ $# -eq 0 ]] || die "check takes no options"; command_check ;;
  download) shift; command_download "$@" ;;
  apply) shift; command_apply "$@" ;;
  -h|--help|help|'') usage ;;
  *) die "Unknown command: $1" ;;
esac
