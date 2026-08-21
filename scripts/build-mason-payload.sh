#!/usr/bin/env bash
# Build the offline Mason payload from config/plugin-manifest.lua.
set -euo pipefail

: "${NVIM:?Set NVIM to the bundled Linux Neovim binary}"
: "${MASON_MANIFEST:?Set MASON_MANIFEST to config/plugin-manifest.lua}"
: "${MASON_OUTPUT:?Set MASON_OUTPUT to the output tarball path}"

config_dir="$HOME/.config/nvim-mason-test"
data_dir="$HOME/.local/share/nvim-mason-test"
mkdir -p "$config_dir"

cat > "$config_dir/init.lua" <<'LUA'
local lazypath = vim.fn.stdpath("data") .. "/lazy-mason/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)
require("lazy").setup({ { "mason-org/mason.nvim" } })
LUA

NVIM_APPNAME=nvim-mason-test "$NVIM" --headless '+Lazy! sync' +qa

installer=$(mktemp "${TMPDIR:-/tmp}/airgap-mason.XXXXXX.lua")
trap 'rm -f "$installer"' EXIT HUP INT TERM
cat > "$installer" <<'LUA'
require("mason").setup()
local registry = require("mason-registry")
local manifest = dofile(vim.env.MASON_MANIFEST)
local packages = {}
for _, group in ipairs({ "lsp_servers", "formatters", "linters" }) do
  for _, package_name in ipairs(manifest.mason[group] or {}) do
    table.insert(packages, package_name)
  end
end

registry.refresh()
local completed, failures = 0, {}
for _, package_name in ipairs(packages) do
  if not registry.has_package(package_name) then
    error("Mason registry is missing package: " .. package_name)
  end
  local package = registry.get_package(package_name)
  if package:is_installed() then
    completed = completed + 1
  else
    package:once("closed", function()
      if package:is_installed() then
        completed = completed + 1
      else
        table.insert(failures, package_name)
      end
    end)
    package:install()
  end
end

if not vim.wait(300000, function() return completed + #failures == #packages end, 500) then
  error("Timed out while installing Mason packages")
end
if #failures > 0 then
  error("Mason failed to install: " .. table.concat(failures, ", "))
end
LUA

MASON_MANIFEST="$MASON_MANIFEST" \
  NVIM_APPNAME=nvim-mason-test "$NVIM" --headless -c "luafile $installer" -c qa

packages_dir="$data_dir/mason/packages"
test -d "$packages_dir"
test -x "$data_dir/mason/bin/gopls"
test -x "$data_dir/mason/bin/bash-language-server"

# JavaScript-based Mason tools need a runtime after transfer to the offline host.
node_version=v22.23.2
node_tarball="node-${node_version}-linux-x64.tar.xz"
node_url="https://nodejs.org/dist/${node_version}/${node_tarball}"
node_dir=$(mktemp -d "${TMPDIR:-/tmp}/airgap-node.XXXXXX")
trap 'rm -f "$installer"; rm -rf "$node_dir"' EXIT HUP INT TERM
curl -fsSL "$node_url" -o "$node_dir/$node_tarball"
curl -fsSL "https://nodejs.org/dist/${node_version}/SHASUMS256.txt" -o "$node_dir/SHASUMS256.txt"
(cd "$node_dir" && grep " ${node_tarball}$" SHASUMS256.txt | sha256sum -c -)
mkdir -p "$data_dir/mason/node"
tar -xJf "$node_dir/$node_tarball" --strip-components=1 -C "$data_dir/mason/node"
test -x "$data_dir/mason/node/bin/node"

mkdir -p "$(dirname "$MASON_OUTPUT")"
tar -C "$data_dir" -czf "$MASON_OUTPUT" mason
