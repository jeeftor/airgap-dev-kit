#!/usr/bin/env bash
# Verify patch-release calculation without creating a real tag or GitHub release.
set -euo pipefail

repo_root=$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)
tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/airgap-release-patch-test.XXXXXX")
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM
mkdir -p "$tmp_dir/bin"

cat > "$tmp_dir/bin/git" <<'EOF'
#!/bin/sh
case "$*" in
  *'branch --show-current'*) echo master ;;
  *'diff --quiet'*|*'diff --cached --quiet'*|*'fetch origin master --tags'*) ;;
  *'status --porcelain'*) ;;
  *'rev-parse HEAD'*) echo deadbeef ;;
  *'rev-parse origin/master'*) echo deadbeef ;;
  *'tag -l'*) echo v2.1.13 ;;
  *'tag -a v2.1.14'*) echo "$*" >> "$AIRGAP_TEST_LOG" ;;
  *'push origin v2.1.14'*) echo "$*" >> "$AIRGAP_TEST_LOG" ;;
  *) echo "unexpected git call: $*" >&2; exit 1 ;;
esac
EOF
cat > "$tmp_dir/bin/gh" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "$tmp_dir/bin/git" "$tmp_dir/bin/gh"

AIRGAP_TEST_LOG="$tmp_dir/git.log" \
PATH="$tmp_dir/bin:$PATH" \
ARCHES=linux-x86_64 WAIT=0 DIST_DIR="$tmp_dir/dist" \
  bash "$repo_root/scripts/release-patch.sh" start > "$tmp_dir/output"

grep -F 'Release v2.1.14 started for linux-x86_64.' "$tmp_dir/output" >/dev/null
grep -F 'tag -a v2.1.14 -m Release v2.1.14' "$tmp_dir/git.log" >/dev/null
grep -F 'push origin v2.1.14' "$tmp_dir/git.log" >/dev/null
echo 'patch-release workflow verified'
