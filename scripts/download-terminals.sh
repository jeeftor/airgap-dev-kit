#!/bin/sh
# Download pinned portable Linux terminals on the connected build host.
set -eu
kitty_version=$1
ghostty_version=$2
# Update these digests when changing the pinned versions in Makefile.
case "$kitty_version" in
  0.43.1) kitty_sha=f2026ef8cec6fd21b58e3ae501f707c2fc922ddb9b3e79685917fc60197449fb ;;
  *) echo "No reviewed Kitty digest for $kitty_version" >&2; exit 1 ;;
esac
case "$ghostty_version" in
  1.4.0) ghostty_sha=50ad4f8b54a01e7d41426e7d12ffae9c88aa1c516ac140755e2bca596e1d2ae6 ;;
  *) echo "No reviewed Ghostty digest for $ghostty_version" >&2; exit 1 ;;
esac
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT HUP INT TERM
verify() {
  if command -v sha256sum >/dev/null 2>&1; then
    actual=$(sha256sum "$1" | awk '{print $1}')
  else
    actual=$(shasum -a 256 "$1" | awk '{print $1}')
  fi
  [ "$actual" = "$2" ] || { echo "Checksum mismatch: $1" >&2; exit 1; }
}
mkdir -p offline-packages/linux
if [ ! -f offline-packages/linux/kitty.tar.gz ]; then
  curl -fsSL "https://github.com/kovidgoyal/kitty/releases/download/v$kitty_version/kitty-$kitty_version-x86_64.txz" -o "$stage/kitty.txz"
  verify "$stage/kitty.txz" "$kitty_sha"
  mkdir "$stage/kitty"
  tar -xJf "$stage/kitty.txz" -C "$stage/kitty"
  # The target installer uses Go's gzip reader, so targets do not need xz.
  COPYFILE_DISABLE=1 tar -czf "$stage/kitty.tar.gz" -C "$stage/kitty" bin lib share
  mv "$stage/kitty.tar.gz" offline-packages/linux/kitty.tar.gz
fi
if [ ! -f offline-packages/linux/ghostty.AppImage ]; then
  curl -fsSL "https://github.com/pkgforge-dev/ghostty-appimage/releases/download/v$ghostty_version/Ghostty-$ghostty_version-x86_64.AppImage" -o "$stage/ghostty.AppImage"
  verify "$stage/ghostty.AppImage" "$ghostty_sha"
  chmod +x "$stage/ghostty.AppImage"
  mv "$stage/ghostty.AppImage" offline-packages/linux/ghostty.AppImage
fi
