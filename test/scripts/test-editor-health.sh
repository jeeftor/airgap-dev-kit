#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/../.." && pwd)
archive=${1:?Pass the packaged Linux kit archive}
results=${AIRGAP_HEALTH_RESULTS:-/tmp/airgap-editor-health-results}
suite=${AIRGAP_EDITOR_SUITE:-all}
case "$suite" in
  all|core|languages|formatting|plugins|minimal|projects) ;;
  *) echo "Unknown editor suite: $suite" >&2; exit 2 ;;
esac
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
  AIRGAP_INTEGRATION_SCRIPT="$repo_root/test/scripts/editor-integration.lua" AIRGAP_EDITOR_SUITE="$suite" \
  AIRGAP_PROJECT_SCRIPT="$repo_root/test/scripts/editor-projects.lua" \
  AIRGAP_TEST_KIT="$kit" bash <<'SH'
set -euo pipefail
trap 'cp "$XDG_STATE_HOME/nvim/lsp.log" "$AIRGAP_HEALTH_RESULTS/lsp.log" 2>/dev/null || true' EXIT
"$AIRGAP_TEST_KIT/airgap" install --yes --cli-only --nvim-mode=replace --configure-shell=false 2>&1 | tee "$AIRGAP_HEALTH_RESULTS/install.log"
export PATH="$HOME/.local/bin:$PATH"
unset NVIM_APPNAME VIMINIT EXINIT VIMRUNTIME
export GOPROXY=off GOTOOLCHAIN=local CARGO_NET_OFFLINE=true
# Capture the installed lockfile before any startup can try to change it.
cp "$XDG_DATA_HOME/nvim/lazy-lock.json" "$AIRGAP_HEALTH_RESULTS/lazy-lock-before.json"
# Let VimEnter and scheduled plugin setup finish before testing and capturing
# health. Immediate +checkhealth/+qa can report setup that has not run yet.
timeout 90s nvim --headless -c 'lua vim.defer_fn(function() local ok, err = pcall(dofile, vim.env.AIRGAP_HEALTH_SCRIPT); if not ok then print(err) end; vim.cmd("checkhealth"); vim.fn.writefile(vim.api.nvim_buf_get_lines(0, 0, -1, false), vim.env.AIRGAP_HEALTH_RESULTS .. "/checkhealth.txt"); vim.cmd(ok and "qa!" or "cquit 1") end, 200)' > "$AIRGAP_HEALTH_RESULTS/behavior.txt" 2>&1 \
  || { cat "$AIRGAP_HEALTH_RESULTS/behavior.txt"; exit 1; }
rg -q 'Offline editor parsers, queries, highlighting, CLI, and yank verified' "$AIRGAP_HEALTH_RESULTS/behavior.txt"
# Optional provider and disabled-feature diagnostics remain in the full buffer.
test -s "$AIRGAP_HEALTH_RESULTS/checkhealth.txt"
cat "$AIRGAP_HEALTH_RESULTS/behavior.txt"
if [[ "$AIRGAP_EDITOR_SUITE" != core ]]; then
  # Collect all case failures, rather than stopping after the first broken server.
  timeout 900s nvim --headless -c 'lua vim.defer_fn(function() local ok, err = pcall(dofile, vim.env.AIRGAP_INTEGRATION_SCRIPT); if not ok then print(err) end; vim.cmd(ok and "qa!" or "cquit 1") end, 200)' \
    > "$AIRGAP_HEALTH_RESULTS/integration.txt" 2>&1 || { cat "$AIRGAP_HEALTH_RESULTS/integration.txt"; exit 1; }
  cat "$AIRGAP_HEALTH_RESULTS/integration.txt"
fi
# Two real editor processes must preserve saved content and bundled plugin state.
export AIRGAP_RESTART_FILE="$XDG_CACHE_HOME/restart-fixture.lua"
timeout 30s nvim --headless -c 'lua vim.cmd.edit(vim.env.AIRGAP_RESTART_FILE); vim.api.nvim_buf_set_lines(0, 0, -1, false, {"print(42)"}); vim.cmd.write(); vim.cmd("qa!")' \
  > "$AIRGAP_HEALTH_RESULTS/restart-write.txt" 2>&1
timeout 30s nvim --headless -c 'lua vim.cmd.edit(vim.env.AIRGAP_RESTART_FILE); assert(vim.api.nvim_get_current_line() == "print(42)", "Saved content lost across restart"); assert(require("lazy.core.config").options.install.missing == false); vim.cmd("qa!")' \
  > "$AIRGAP_HEALTH_RESULTS/restart-read.txt" 2>&1
cmp "$AIRGAP_HEALTH_RESULTS/lazy-lock-before.json" "$XDG_DATA_HOME/nvim/lazy-lock.json"
echo 'PASS offline save/restart and unchanged plugin lockfile'
SH
