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
awk '$0 == "site/parser/lua.so" { found = 1 } END { exit !found }' "$results/payload-files.txt" || { echo 'Missing bundled Lua parser' >&2; exit 1; }
awk '$0 == "site/bin/tree-sitter" { found = 1 } END { exit !found }' "$results/payload-files.txt" || { echo 'Missing bundled Tree-sitter CLI' >&2; exit 1; }

test_home="$work_dir/home"
mkdir -p "$test_home"
env HOME="$test_home" XDG_CONFIG_HOME="$test_home/.config" \
  XDG_DATA_HOME="$test_home/.local/share" XDG_STATE_HOME="$test_home/.local/state" \
  XDG_CACHE_HOME="$test_home/.cache" AIRGAP_PARSER_MANIFEST="$repo_root/config/plugin-manifest.lua" \
  AIRGAP_HEALTH_RESULTS="$results" AIRGAP_HEALTH_SCRIPT="$repo_root/test/scripts/editor-health.lua" \
  AIRGAP_TEST_KIT="$kit" bash <<'SH'
set -euo pipefail
trap 'cp "$XDG_STATE_HOME/nvim/lsp.log" "$AIRGAP_HEALTH_RESULTS/lsp.log" 2>/dev/null || true' EXIT
"$AIRGAP_TEST_KIT/airgap" install --yes --cli-only --nvim-mode=replace --configure-shell=false
export PATH="$HOME/.local/bin:$PATH"
# Let VimEnter and scheduled plugin setup finish before testing and capturing
# health. Immediate +checkhealth/+qa can report setup that has not run yet.
timeout 90s nvim --headless -c 'lua vim.defer_fn(function() local ok, err = pcall(dofile, vim.env.AIRGAP_HEALTH_SCRIPT); if not ok then print(err) end; vim.cmd("checkhealth"); vim.fn.writefile(vim.api.nvim_buf_get_lines(0, 0, -1, false), vim.env.AIRGAP_HEALTH_RESULTS .. "/checkhealth.txt"); vim.cmd(ok and "qa!" or "cquit 1") end, 200)' > "$AIRGAP_HEALTH_RESULTS/behavior.txt" 2>&1
rg -q 'Offline editor parsers, queries, highlighting, CLI, and yank verified' "$AIRGAP_HEALTH_RESULTS/behavior.txt"
# Optional provider and disabled-feature diagnostics remain in the full buffer.
test -s "$AIRGAP_HEALTH_RESULTS/checkhealth.txt"
cat "$AIRGAP_HEALTH_RESULTS/behavior.txt"
SH
