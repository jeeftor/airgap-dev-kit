#!/usr/bin/env bash
# Build the offline LazyVim payload from the pinned Neovim configuration.
set -euo pipefail

: "${NVIM:?Set NVIM to the bundled Linux Neovim binary}"
: "${LAZY_CONFIG:?Set LAZY_CONFIG to config/nvim/.config/nvim}"
: "${LAZY_OUTPUT:?Set LAZY_OUTPUT to the output tarball path}"
: "${PARSER_MANIFEST:?Set PARSER_MANIFEST to config/plugin-manifest.lua}"
: "${TREE_SITTER_VERSION:?Set the pinned Tree-sitter CLI release}"
: "${TREE_SITTER_SHA256:?Set the Tree-sitter release asset checksum}"

work_dir=$(mktemp -d "${TMPDIR:-/tmp}/airgap-lazy.XXXXXX")
trap 'rm -rf "$work_dir"' EXIT HUP INT TERM

config_home="$work_dir/config"
data_home="$work_dir/data"
state_home="$work_dir/state"
cache_home="$work_dir/cache"
config_dir="$config_home/nvim"

mkdir -p "$config_dir"
cp -R "$LAZY_CONFIG/." "$config_dir/"

# Lazy reads its lockfile from the data directory, so seed that path before sync.
mkdir -p "$data_home/nvim"
if [ -f "$config_dir/lazy-lock.json" ]; then
  cp "$config_dir/lazy-lock.json" "$data_home/nvim/lazy-lock.json"
fi

# The checked-in configuration is intentionally offline-first. Permit this
# one connected build to fetch exactly the lockfile-pinned plugin set.
lazy_config_file="$config_dir/lua/config/lazy.lua"
sed 's/missing = false/missing = true/' "$lazy_config_file" > "$lazy_config_file.tmp"
mv "$lazy_config_file.tmp" "$lazy_config_file"

# Synchronize plugin sources first; compile parsers separately below so failed
# downloads or builds cannot silently produce an incomplete offline archive.
cat > "$config_dir/lua/plugins/zz-airgap-payload-build.lua" <<'EOF'
return {
  { "mason-org/mason.nvim", config = false },
  { "mason-org/mason-lspconfig.nvim", config = false },
  { "nvim-treesitter/nvim-treesitter", config = false },
}
EOF

XDG_CONFIG_HOME="$config_home" \
XDG_DATA_HOME="$data_home" \
XDG_STATE_HOME="$state_home" \
XDG_CACHE_HOME="$cache_home" \
  "$NVIM" --headless '+lua require("lazy").sync({wait = true, lockfile = true})' +qa

lazy_dir="$data_home/nvim/lazy"
test -d "$lazy_dir"
test -f "$data_home/nvim/lazy-lock.json"

site_dir="$data_home/nvim/site"
mkdir -p "$site_dir/bin"
curl -fsSL "https://github.com/tree-sitter/tree-sitter/releases/download/${TREE_SITTER_VERSION}/tree-sitter-linux-x64.gz" -o "$work_dir/tree-sitter.gz"
printf '%s  %s\n' "$TREE_SITTER_SHA256" "$work_dir/tree-sitter.gz" | sha256sum -c -
gzip -dc "$work_dir/tree-sitter.gz" > "$site_dir/bin/tree-sitter"
chmod 0755 "$site_dir/bin/tree-sitter"
"$site_dir/bin/tree-sitter" --version

cat > "$work_dir/build-parsers.lua" <<'LUA'
local expected = vim.json.decode(table.concat(vim.fn.readfile(vim.env.AIRGAP_LOCKFILE), "\n"))
for name, entry in pairs(expected) do
  local result = vim.system({ "git", "-C", vim.env.AIRGAP_LAZY_DIR .. "/" .. name, "rev-parse", "HEAD" }, { text = true }):wait()
  assert(result.code == 0 and vim.trim(result.stdout) == entry.commit, "Plugin not at locked revision: " .. name)
end
vim.opt.rtp:prepend(vim.env.AIRGAP_TS_PLUGIN)
local ts = require("nvim-treesitter")
ts.setup({ install_dir = vim.env.AIRGAP_TS_SITE })
local languages = dofile(vim.env.PARSER_MANIFEST).treesitter
ts.install(languages):wait(300000)
for _, language in ipairs(languages) do
  local parser = vim.env.AIRGAP_TS_SITE .. "/parser/" .. language .. ".so"
  assert(vim.fn.filereadable(parser) == 1, "Missing compiled parser: " .. language)
  assert(vim.treesitter.language.add(language, { path = parser }), "Cannot load parser: " .. language)
  assert(vim.treesitter.query.get(language, "highlights"), "Missing highlight queries: " .. language)
end
LUA
PATH="$site_dir/bin:$PATH" \
AIRGAP_LOCKFILE="$LAZY_CONFIG/lazy-lock.json" AIRGAP_LAZY_DIR="$lazy_dir" \
AIRGAP_TS_PLUGIN="$lazy_dir/nvim-treesitter" AIRGAP_TS_SITE="$site_dir" \
  "$NVIM" --headless -u NONE -i NONE -l "$work_dir/build-parsers.lua"

mkdir -p "$(dirname "$LAZY_OUTPUT")"
tar -C "$data_home/nvim" -czf "$LAZY_OUTPUT" lazy lazy-lock.json site
