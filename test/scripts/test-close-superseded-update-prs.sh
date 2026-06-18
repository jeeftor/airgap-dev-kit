#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

PRS_JSON="$TMP_DIR/prs.json"
EXPECTED="$TMP_DIR/expected.txt"
ACTUAL="$TMP_DIR/actual.txt"

cat > "$PRS_JSON" <<'EOF'
[
  {"number": 1, "headRefName": "auto-update/bat", "url": "https://example.test/pull/1"},
  {"number": 2, "headRefName": "auto-update/bat-0.25.0", "url": "https://example.test/pull/2"},
  {"number": 3, "headRefName": "auto-update/bat-v0.26.0", "url": "https://example.test/pull/3"},
  {"number": 4, "headRefName": "auto-update/fzf-0.73.1", "url": "https://example.test/pull/4"},
  {"number": 5, "headRefName": "auto-update/batman-1.0.0", "url": "https://example.test/pull/5"}
]
EOF

cat > "$EXPECTED" <<'EOF'
2	auto-update/bat-0.25.0	https://example.test/pull/2
3	auto-update/bat-v0.26.0	https://example.test/pull/3
EOF

bash "$ROOT_DIR/scripts/close-superseded-update-prs.sh" \
  --tool bat \
  --keep-branch auto-update/bat \
  --list-file "$PRS_JSON" \
  --dry-run > "$ACTUAL"

diff -u "$EXPECTED" "$ACTUAL"

echo "superseded update PR selection tests passed"
