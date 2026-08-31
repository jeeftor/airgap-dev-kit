#!/usr/bin/env bash
# Download, verify, and install the Linux kit that shipped with this bootstrap.
set -euo pipefail

repo="${AIRGAP_DEV_KIT_REPO:-jeeftor/airgap-dev-kit}"
api_url="${AIRGAP_DEV_KIT_API_URL:-https://api.github.com}"
# The release workflow replaces this value before publishing this script as a
# release asset. Keeping the tag here prevents a bootstrap downloaded from one
# release from silently installing an archive from a later release.
release_tag="${AIRGAP_DEV_KIT_VERSION:-@RELEASE_TAG@}"
asset="airgap-dev-kit-linux-x86_64.tar.gz"

die() { echo "airgap installer: $*" >&2; exit 1; }
command -v curl >/dev/null 2>&1 || die "curl is required"
command -v python3 >/dev/null 2>&1 || die "python3 is required"
command -v tar >/dev/null 2>&1 || die "tar is required"
command -v sha256sum >/dev/null 2>&1 || die "sha256sum is required"
[[ "$(uname -s)" == Linux && "$(uname -m)" == x86_64 ]] || die "only Linux x86_64 is currently published"
[[ "$release_tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "bootstrap is not bound to a release tag"

workdir=$(mktemp -d "${TMPDIR:-/tmp}/airgap-install.XXXXXX")
trap 'rm -rf "$workdir"' EXIT
release=$(curl -fsSL "$api_url/repos/$repo/releases/tags/$release_tag")
readarray -t fields < <(printf '%s' "$release" | python3 -c '
import json, sys
r = json.load(sys.stdin)
assets = {a["name"]: a["browser_download_url"] for a in r.get("assets", [])}
for name in ("tag_name", "airgap-dev-kit-linux-x86_64.tar.gz", "checksums.txt"):
    print(r.get(name, "") if name == "tag_name" else assets.get(name, ""))
')
tag="${fields[0]:-}" archive_url="${fields[1]:-}" checksums_url="${fields[2]:-}"
[[ "$tag" == "$release_tag" ]] || die "release metadata does not match bootstrap tag $release_tag"
[[ -n "$archive_url" && -n "$checksums_url" ]] || die "release $release_tag lacks the Linux kit or checksums"
curl -fL --retry 4 -o "$workdir/$asset" "$archive_url"
curl -fL --retry 4 -o "$workdir/checksums.txt" "$checksums_url"
(cd "$workdir" && grep " $asset$" checksums.txt | sha256sum -c -)
tar -xzf "$workdir/$asset" -C "$workdir"
cd "$workdir/airgap-dev-kit"
./airgap doctor --verify
exec ./airgap install --yes "$@"
