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
vim.opt.rtp:prepend(vim.fn.stdpath("data") .. "/lazy/mason.nvim")
require("mason").setup()
local registry = require("mason-registry")
local manifest = dofile(vim.env.MASON_MANIFEST)
local packages = {}
for _, group in ipairs({ "lsp_servers", "formatters", "linters" }) do
  for _, package_name in ipairs(manifest.mason[group] or {}) do
    table.insert(packages, package_name)
  end
end

local registry_ready, registry_success, registry_errors = false, false, nil
registry.refresh(function(success, errors)
  registry_success, registry_errors, registry_ready = success, errors, true
end)
assert(vim.wait(300000, function() return registry_ready end, 100), "Timed out refreshing Mason registry")
assert(registry_success, "Mason registry refresh failed: " .. vim.inspect(registry_errors))
local installs = {}
for _, package_name in ipairs(packages) do
  if not registry.has_package(package_name) then
    error("Mason registry is missing package: " .. package_name)
  end
  local package = registry.get_package(package_name)
  if not package:is_installed() then
    -- closed belongs to the returned InstallHandle, not the Package emitter.
    installs[package_name] = package:install()
  end
end

local finished = vim.wait(300000, function()
  for _, handle in pairs(installs) do
    if not handle:is_closed() then return false end
  end
  return true
end, 100)
local failures = {}
for _, package_name in ipairs(packages) do
  local handle = installs[package_name]
  if (handle and not handle:is_closed()) or not registry.get_package(package_name):is_installed() then
    table.insert(failures, package_name)
    io.stderr:write("Mason package failed or unfinished: " .. package_name .. "\n")
    if handle then
      io.stderr:write("Install state: " .. handle.state .. "\n")
      for _, stream in ipairs({ "stdout", "stderr" }) do
        io.stderr:write(table.concat(handle.stdio_sink.buffers[stream]))
      end
      if not handle:is_closed() then handle:terminate() end
    end
  end
end
assert(finished and #failures == 0, "Mason packages missing or unfinished: " .. table.concat(failures, ", ")
  .. "; see " .. vim.fn.stdpath("log") .. "/mason.log")
print("All " .. #packages .. " manifest Mason packages installed")
LUA

# Script mode propagates Lua failures as a nonzero exit; :luafile followed by
# :qa can otherwise report an error and still let an incomplete archive publish.
MASON_MANIFEST="$MASON_MANIFEST" \
  NVIM_APPNAME=nvim-mason-test "$NVIM" --headless -u NONE -i NONE -l "$installer"

packages_dir="$data_dir/mason/packages"
test -d "$packages_dir"
test -x "$data_dir/mason/bin/gopls"
test -x "$data_dir/mason/bin/bash-language-server"

# Mason generates this launcher with an absolute build-host path. Resolve its
# package through the bin symlink so it also works after offline extraction.
cat > "$packages_dir/lua-language-server/lua-language-server" <<'SH'
#!/bin/sh
set -eu
launcher=$(readlink -f -- "$0")
exec "$(dirname -- "$launcher")/libexec/bin/lua-language-server" "$@"
SH
chmod +x "$packages_dir/lua-language-server/lua-language-server"

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
