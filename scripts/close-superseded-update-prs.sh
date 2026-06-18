#!/usr/bin/env bash
set -euo pipefail

TOOL=""
KEEP_BRANCH=""
LIST_FILE=""
DRY_RUN=0

usage() {
  cat <<EOF
Usage: scripts/close-superseded-update-prs.sh --tool <tool> --keep-branch <branch> [options]

Options:
  --tool <tool>             Tool slug, for example bat or fzf
  --keep-branch <branch>    Current stable update branch to keep open
  --list-file <path>        Read PR JSON from a file instead of gh pr list
  --dry-run                 Print matching PRs instead of closing them
  -h, --help                Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tool)
      TOOL="$2"
      shift 2
      ;;
    --keep-branch)
      KEEP_BRANCH="$2"
      shift 2
      ;;
    --list-file)
      LIST_FILE="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$TOOL" || -z "$KEEP_BRANCH" ]]; then
  echo "--tool and --keep-branch are required" >&2
  usage
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required to select superseded PRs" >&2
  exit 1
fi

PR_JSON_FILE=""
if [[ -n "$LIST_FILE" ]]; then
  if [[ ! -f "$LIST_FILE" ]]; then
    echo "PR list file not found: $LIST_FILE" >&2
    exit 1
  fi
  PR_JSON_FILE="$LIST_FILE"
else
  if ! command -v gh >/dev/null 2>&1; then
    echo "gh is required unless --list-file is used" >&2
    exit 1
  fi
  PR_JSON_FILE="$(mktemp)"
  trap 'rm -f "$PR_JSON_FILE"' EXIT
  gh pr list --state open --json number,headRefName,url --limit 100 > "$PR_JSON_FILE"
fi

matches="$(
  python3 - "$TOOL" "$KEEP_BRANCH" "$PR_JSON_FILE" <<'PY'
import json
import sys

tool, keep_branch, pr_json_file = sys.argv[1:4]
prefix = f"auto-update/{tool}-"
with open(pr_json_file, encoding="utf-8") as handle:
    prs = json.load(handle)

for pr in prs:
    branch = pr.get("headRefName", "")
    if branch == keep_branch:
        continue
    if branch.startswith(prefix):
        print(f'{pr["number"]}\t{branch}\t{pr.get("url", "")}')
PY
)"

if [[ -z "$matches" ]]; then
  echo "No superseded $TOOL update PRs found." >&2
  exit 0
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  printf '%s\n' "$matches"
  exit 0
fi

while IFS=$'\t' read -r number branch url; do
  [[ -n "$number" ]] || continue
  echo "Closing superseded $TOOL update PR #$number ($branch): $url"
  gh pr close "$number" \
    --delete-branch \
    --comment "Closing this automated update PR because a newer ${TOOL} update is being prepared on \`${KEEP_BRANCH}\`."
done <<<"$matches"
