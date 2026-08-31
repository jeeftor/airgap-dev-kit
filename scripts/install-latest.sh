#!/usr/bin/env bash
# Download, verify, and install the latest published Linux kit.
set -euo pipefail

repo="${AIRGAP_DEV_KIT_REPO:-jeeftor/airgap-dev-kit}"
asset="airgap-dev-kit-linux-x86_64.tar.gz"

die() { echo "airgap installer: $*" >&2; exit 1; }
command -v curl >/dev/null 2>&1 || die "curl is required"
command -v python3 >/dev/null 2>&1 || die "python3 is required"
command -v tar >/dev/null 2>&1 || die "tar is required"
[[ "$(uname -s)" == Linux && "$(uname -m)" == x86_64 ]] || die "only Linux x86_64 is currently published"

workdir=$(mktemp -d "${TMPDIR:-/tmp}/airgap-install.XXXXXX")
trap 'rm -rf "$workdir"' EXIT
release=$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest")
readarray -t fields < <(printf '%s' "$release" | python3 -c '
import json, sys
r = json.load(sys.stdin)
assets = {a["name"]: a["browser_download_url"] for a in r.get("assets", [])}
for name in ("tag_name", "airgap-dev-kit-linux-x86_64.tar.gz", "checksums.txt"):
    print(r.get(name, "") if name == "tag_name" else assets.get(name, ""))
')
tag="${fields[0]:-}" archive_url="${fields[1]:-}" checksums_url="${fields[2]:-}"
[[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+ ]] || die "latest release is not a SemVer kit"
[[ -n "$archive_url" && -n "$checksums_url" ]] || die "release $tag lacks the Linux kit or checksums"
curl -fL --retry 4 -o "$workdir/$asset" "$archive_url"
curl -fL --retry 4 -o "$workdir/checksums.txt" "$checksums_url"
(cd "$workdir" && grep " $asset$" checksums.txt | sha256sum -c -)
tar -xzf "$workdir/$asset" -C "$workdir"
cd "$workdir/airgap-dev-kit"
./airgap doctor --verify
exec ./airgap install --yes "$@"
