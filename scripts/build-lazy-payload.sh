#!/usr/bin/env bash
# Build the offline LazyVim payload from the pinned Neovim configuration.
set -euo pipefail

: "${NVIM:?Set NVIM to the bundled Linux Neovim binary}"
: "${LAZY_CONFIG:?Set LAZY_CONFIG to config/nvim/.config/nvim}"
: "${LAZY_OUTPUT:?Set LAZY_OUTPUT to the output tarball path}"

work_dir=$(mktemp -d "${TMPDIR:-/tmp}/airgap-lazy.XXXXXX")
trap 'rm -rf "$work_dir"' EXIT HUP INT TERM

config_home="$work_dir/config"
data_home="$work_dir/data"
state_home="$work_dir/state"
cache_home="$work_dir/cache"
config_dir="$config_home/nvim"

mkdir -p "$config_dir"
cp -R "$LAZY_CONFIG/." "$config_dir/"

# The checked-in configuration is intentionally offline-first. Permit this
# one connected build to fetch exactly the lockfile-pinned plugin set.
lazy_config_file="$config_dir/lua/config/lazy.lua"
sed 's/missing = false/missing = true/' "$lazy_config_file" > "$lazy_config_file.tmp"
mv "$lazy_config_file.tmp" "$lazy_config_file"

# Mason's air-gapped server list is bundled separately by build-mason-payload.
# Keeping it out of this connected Lazy-only pass prevents LazyVim from asking
# its empty temporary Mason registry to resolve servers before the registry is
# installed. These replacements affect only the temporary copied config.
cat > "$config_dir/lua/plugins/airgap-lsp.lua" <<'EOF'
return {}
EOF
cat > "$config_dir/lua/plugins/mason-airgap.lua" <<'EOF'
return {}
EOF
cat > "$config_dir/lua/plugins/zz-airgap-payload-build.lua" <<'EOF'
return {
  -- LazyVim's Mason bridge still loads while the plugin set is synchronized.
  -- Keep Mason enabled but suppress installations; build-mason-payload.sh
  -- creates the separate offline LSP archive immediately after this pass.
  { "mason-org/mason.nvim", opts = { ensure_installed = {} } },
  { "mason-org/mason-lspconfig.nvim", opts = { ensure_installed = {} } },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      -- Parser binaries are platform-specific and are not part of this plugin
      -- source archive. Avoid Mason's first-run tree-sitter-cli install race.
      opts.ensure_installed = {}
      opts.auto_install = false
    end,
  },
}
EOF

XDG_CONFIG_HOME="$config_home" \
XDG_DATA_HOME="$data_home" \
XDG_STATE_HOME="$state_home" \
XDG_CACHE_HOME="$cache_home" \
  "$NVIM" --headless '+Lazy! sync' +qa || {
    # LazyVim can race its first tree-sitter CLI install. The first pass has
    # already completed the package installation, so one clean retry is safe.
    XDG_CONFIG_HOME="$config_home" \
    XDG_DATA_HOME="$data_home" \
    XDG_STATE_HOME="$state_home" \
    XDG_CACHE_HOME="$cache_home" \
      "$NVIM" --headless '+Lazy! sync' +qa
  }

lazy_dir="$data_home/nvim/lazy"
test -d "$lazy_dir"
test -f "$config_dir/lazy-lock.json"

mkdir -p "$(dirname "$LAZY_OUTPUT")"
cp "$config_dir/lazy-lock.json" "$data_home/nvim/lazy-lock.json"
tar -C "$data_home/nvim" -czf "$LAZY_OUTPUT" lazy lazy-lock.json
