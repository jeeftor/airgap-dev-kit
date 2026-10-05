#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/../.." && pwd)
archive=${1:?Pass the packaged Linux kit archive}
results=${AIRGAP_HEALTH_RESULTS:-/tmp/airgap-editor-health-results}
mkdir -p "$results"
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/airgap-editor-health.XXXXXX")
trap 'rm -rf "$work_dir"' EXIT
tar -xzf "$archive" -C "$work_dir"
kit="$work_dir/airgap-dev-kit"
# Catch incomplete packaging before invoking any editor or installer.
tar -tzf "$kit/offline-packages/lazy-plugins.tar.gz" > "$results/payload-files.txt"
rg -q '^site/parser/lua\.so$' "$results/payload-files.txt" || { echo 'Missing bundled Lua parser' >&2; exit 1; }
rg -q '^site/bin/tree-sitter$' "$results/payload-files.txt" || { echo 'Missing bundled Tree-sitter CLI' >&2; exit 1; }

test_home="$work_dir/home"
mkdir -p "$test_home"
env HOME="$test_home" XDG_CONFIG_HOME="$test_home/.config" \
  XDG_DATA_HOME="$test_home/.local/share" XDG_STATE_HOME="$test_home/.local/state" \
  XDG_CACHE_HOME="$test_home/.cache" AIRGAP_PARSER_MANIFEST="$repo_root/config/plugin-manifest.lua" \
  AIRGAP_HEALTH_RESULTS="$results" AIRGAP_HEALTH_SCRIPT="$repo_root/test/scripts/editor-health.lua" \
  AIRGAP_TEST_KIT="$kit" bash <<'SH'
set -euo pipefail
"$AIRGAP_TEST_KIT/airgap" install --yes --cli-only --nvim-mode=replace --configure-shell=false
export PATH="$HOME/.local/bin:$PATH"
# -l does not load the normal profile; use :luafile after normal startup instead.
nvim --headless '+lua dofile(vim.env.AIRGAP_HEALTH_SCRIPT)' '+qa!' > "$AIRGAP_HEALTH_RESULTS/behavior.txt" 2>&1
rg -q 'Offline editor parsers, queries, highlighting, CLI, and yank verified' "$AIRGAP_HEALTH_RESULTS/behavior.txt"
# Retain the full diagnostic buffer. Optional provider/UI warnings are not gates.
nvim --headless '+checkhealth' '+lua vim.fn.writefile(vim.api.nvim_buf_get_lines(0, 0, -1, false), vim.env.AIRGAP_HEALTH_RESULTS .. "/checkhealth.txt")' '+qa!' \
  > "$AIRGAP_HEALTH_RESULTS/startup.txt" 2>&1
test -s "$AIRGAP_HEALTH_RESULTS/checkhealth.txt"
cat "$AIRGAP_HEALTH_RESULTS/behavior.txt"
SH
