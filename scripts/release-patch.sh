#!/usr/bin/env bash
# Start a patch release and optionally wait for/download its published assets.
set -euo pipefail

repo_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
repo="${AIRGAP_RELEASE_REPO:-jeeftor/airgap-dev-kit}"
arches="${ARCHES:-}"
wait_for_release="${WAIT:-0}"
dist_dir="${DIST_DIR:-$repo_root/dist}"

die() { echo "Error: $*" >&2; exit 1; }

select_arches() {
  if [ -n "$arches" ]; then
    return
  fi
  if [ -t 0 ]; then
    printf 'Release architecture(s) [linux-x86_64]: ' >&2
    IFS= read -r arches
  fi
  arches=${arches:-linux-x86_64}
}

validate_arches() {
  case ",$arches," in
    *,linux-x86_64,*) ;;
    *) die "Only linux-x86_64 is published today (got: $arches)" ;;
  esac
  [ "$arches" = "linux-x86_64" ] || die "Multiple architectures are not published today (got: $arches)"
}

next_patch_tag() {
  local latest version major minor patch
  latest=$(git -C "$repo_root" tag -l 'v[0-9]*.[0-9]*.[0-9]*' --sort=-version:refname | head -n 1)
  [ -n "$latest" ] || die "No vX.Y.Z tag exists to bump"
  version=${latest#v}
  IFS=. read -r major minor patch <<EOF
$version
EOF
  [[ "$major" =~ ^[0-9]+$ && "$minor" =~ ^[0-9]+$ && "$patch" =~ ^[0-9]+$ ]] || die "Latest tag is not a patch SemVer tag: $latest"
  printf 'v%s.%s.%s\n' "$major" "$minor" "$((patch + 1))"
}

assert_release_branch() {
  [ "$(git -C "$repo_root" branch --show-current)" = "master" ] || die "Run this from master"
  git -C "$repo_root" diff --quiet || die "Working tree has unstaged changes"
  git -C "$repo_root" diff --cached --quiet || die "Working tree has staged changes"
  [ -z "$(git -C "$repo_root" status --porcelain)" ] || die "Working tree has untracked changes"
  git -C "$repo_root" fetch origin master --tags
  [ "$(git -C "$repo_root" rev-parse HEAD)" = "$(git -C "$repo_root" rev-parse origin/master)" ] || die "master is not synchronized with origin/master"
}

release_run_id() {
  local tag=$1 run_id attempt=0
  while [ "$attempt" -lt 20 ]; do
    run_id=$(gh run list --repo "$repo" --workflow release.yml --branch "$tag" --limit 1 --json databaseId --jq '.[0].databaseId')
    [ -n "$run_id" ] && { printf '%s\n' "$run_id"; return; }
    sleep 3
    attempt=$((attempt + 1))
  done
  die "Release workflow for $tag was not created"
}

download() {
  local tag=${1:-} asset="airgap-dev-kit-linux-x86_64.tar.gz" target_dir
  if [ -z "$tag" ]; then
    tag=$(gh release view --repo "$repo" --json tagName --jq '.tagName') || die "Could not determine the latest release"
    [ -n "$tag" ] || die "Could not determine the latest release"
    printf 'Downloading latest published release: %s\n' "$tag"
  fi
  target_dir="$dist_dir/$tag"
  mkdir -p "$target_dir"
  gh release download "$tag" --repo "$repo" --dir "$target_dir" --pattern "$asset" --pattern checksums.txt --clobber
  (
    cd "$target_dir"
    if command -v sha256sum >/dev/null 2>&1; then sha256sum -c checksums.txt; else shasum -a 256 -c checksums.txt; fi
  )
  gh attestation verify "$target_dir/$asset" --repo "$repo"
  printf 'Verified release assets: %s\n' "$target_dir"
}

start() {
  local tag run_id
  command -v gh >/dev/null 2>&1 || die "gh is required"
  select_arches
  validate_arches
  assert_release_branch
  tag=$(next_patch_tag)
  git -C "$repo_root" tag -a "$tag" -m "Release $tag"
  git -C "$repo_root" push origin "$tag"
  printf 'Release %s started for %s.\n' "$tag" "$arches"
  if [ "$wait_for_release" = "1" ]; then
    run_id=$(release_run_id "$tag")
    gh run watch "$run_id" --repo "$repo" --exit-status
    download "$tag"
  else
    printf 'Watch:    gh run list --repo %s --workflow release.yml --branch %s\n' "$repo" "$tag"
    printf 'Download: make release-download VERSION=%s ARCHES=%s DIST_DIR=%s\n' "$tag" "$arches" "$dist_dir"
  fi
}

case "${1:-}" in
  start) start ;;
  download) [ "$#" -le 2 ] || die "Usage: $0 download [vX.Y.Z]"; select_arches; validate_arches; download "${2:-}" ;;
  *) die "Usage: $0 <start|download [vX.Y.Z]>" ;;
esac
