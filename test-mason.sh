#!/bin/bash
# Test script for Mason LSP installation in Docker
# This mimics what GitHub Actions does but in a local container

set -e

echo "=========================================="
echo "Testing Mason LSP Installation"
echo "=========================================="

# Create minimal Mason config
mkdir -p ~/.config/nvim-mason-test

cat > ~/.config/nvim-mason-test/init.lua <<'EOF'
-- Minimal config for Mason LSP installation
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  print("Cloning lazy.nvim...")
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  {
    "williamboman/mason.nvim",
    build = ":MasonUpdate",
  },
})
EOF

echo ""
echo "Step 1: Installing lazy.nvim and Mason plugin..."
NVIM_APPNAME=nvim-mason-test nvim --headless "+Lazy! sync" +qa
echo "✓ Mason plugin installed"

echo ""
echo "Step 2: Installing LSP servers..."
cat > /tmp/mason-install.lua <<'EOF'
-- Initialize Mason
require("mason").setup()
local registry = require("mason-registry")

local packages = {
  "lua-language-server",
  "pyright",
  "typescript-language-server",
  "bash-language-server",
  "vscode-langservers-extracted",
  "yaml-language-server",
  "gopls",
  "rust-analyzer",
  "clangd",
  "stylua",
  "black",
  "prettier",
  "shfmt",
  "shellcheck",
  "eslint_d",
  "flake8"
}

print("\n=== Testing Mason Registry ===")
print("Refreshing registry...")
registry.refresh()

-- Wait a bit for refresh to complete
vim.wait(2000)

print("\nTrying to get packages...")
local found = 0
local missing = {}

for _, pkg_name in ipairs(packages) do
  local ok, pkg = pcall(registry.get_package, pkg_name)
  if ok then
    print(string.format("  ✓ Found: %s", pkg_name))
    found = found + 1
  else
    print(string.format("  ✗ Not found: %s", pkg_name))
    table.insert(missing, pkg_name)
  end
end

print(string.format("\n=== Summary ==="))
print(string.format("Found: %d/%d packages", found, #packages))

if #missing > 0 then
  print("\nMissing packages:")
  for _, name in ipairs(missing) do
    print("  - " .. name)
  end
end

-- Try to install a simple package as a test
if found > 0 then
  print("\n=== Testing Installation ===")
  print("Attempting to install stylua as a test...")

  local ok, pkg = pcall(registry.get_package, "stylua")
  if ok and not pkg:is_installed() then
    print("Starting installation...")
    pkg:install():once("closed", function()
      if pkg:is_installed() then
        print("✓ stylua installed successfully!")
      else
        print("✗ stylua installation failed")
      end
    end)

    -- Wait for installation
    local max_wait = 60
    for i = 1, max_wait do
      if pkg:is_installed() then
        print(string.format("Installation completed in %d seconds", i))
        break
      end
      if i % 10 == 0 then
        print(string.format("  Waiting... %d seconds", i))
      end
      vim.wait(1000)
    end
  elseif ok and pkg:is_installed() then
    print("✓ stylua already installed")
  end
end

-- Show what's actually installed
local installed = registry:get_installed_packages()
print(string.format("\n=== Installed Packages (%d) ===", #installed))
for _, pkg in ipairs(installed) do
  print("  ✓ " .. pkg.name)
end
EOF

NVIM_APPNAME=nvim-mason-test nvim --headless -c "luafile /tmp/mason-install.lua" -c "qa"

echo ""
echo "=========================================="
echo "Checking Mason packages directory..."
echo "=========================================="

MASON_DIR="$HOME/.local/share/nvim-mason-test/mason/packages"
if [[ -d "$MASON_DIR" ]]; then
  COUNT=$(ls -1 "$MASON_DIR" | wc -l)
  echo "✓ Found $COUNT packages in $MASON_DIR"
  echo ""
  echo "Installed packages:"
  ls -1 "$MASON_DIR"
else
  echo "⚠ Mason packages directory not found"
fi

echo ""
echo "=========================================="
echo "Test Complete"
echo "=========================================="
