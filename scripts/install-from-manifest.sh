#!/bin/bash
# Install LazyVim plugins and Mason packages from plugin-manifest.lua
# This script is used by:
#   - Local Docker testing
#   - GitHub Actions workflows
#   - Final package builds
#
# Usage: ./install-from-manifest.sh [manifest-path]

set -e

# Enable command echoing for debugging
set -x

MANIFEST="${1:-/workspace/config/plugin-manifest.lua}"
WORKSPACE="${WORKSPACE:-$(pwd)}"

echo "=========================================="
echo "📦 Installing from Plugin Manifest"
echo "=========================================="
echo "Manifest: $MANIFEST"
echo "Workspace: $WORKSPACE"
echo ""

# Step 1: Clean slate
echo "🧹 Step 1: Clean slate..."
rm -rf ~/.config/nvim ~/.local/share/nvim ~/.local/state/nvim ~/.cache/nvim
echo "✅ Clean"
echo ""

# Step 2: Clone LazyVim starter
echo "📥 Step 2: Clone LazyVim starter..."
git clone --depth 1 https://github.com/LazyVim/starter ~/.config/nvim
rm -rf ~/.config/nvim/.git
echo "✅ LazyVim starter ready"
echo ""

# Step 3: Generate config from manifest
echo "🔧 Step 3: Generate config from manifest..."

# Create init.lua that loads the manifest
cat > ~/.config/nvim/lua/config/manifest-loader.lua << 'LOADER_EOF'
-- Load plugin manifest and convert to LazyVim config
local manifest_path = os.getenv("MANIFEST_PATH") or "/workspace/config/plugin-manifest.lua"

-- Check if manifest exists
local manifest_file = io.open(manifest_path, "r")
if not manifest_file then
  vim.notify("Manifest not found: " .. manifest_path, vim.log.levels.ERROR)
  return {}
end
manifest_file:close()

-- Load manifest
local manifest = dofile(manifest_path)

-- Build plugin specs from manifest
local specs = {}

-- Add extra plugins
if manifest.plugins and manifest.plugins.extras then
  for _, plugin in ipairs(manifest.plugins.extras) do
    table.insert(specs, { plugin })
  end
end

-- Import LazyVim extras
if manifest.lazyvim_extras then
  for _, extra in ipairs(manifest.lazyvim_extras) do
    table.insert(specs, { import = extra })
  end
end

-- Configure Mason
if manifest.mason then
  -- Collect all Mason packages
  local mason_packages = {}

  if manifest.mason.lsp_servers then
    vim.list_extend(mason_packages, manifest.mason.lsp_servers)
  end
  if manifest.mason.formatters then
    vim.list_extend(mason_packages, manifest.mason.formatters)
  end
  if manifest.mason.linters then
    vim.list_extend(mason_packages, manifest.mason.linters)
  end

  -- Mason config (using correct org names)
  table.insert(specs, {
    "mason-org/mason.nvim",
    opts = {
      -- Don't use ensure_installed here, let mason-tool-installer handle it
    },
  })

  -- Mason LSP config (using correct org name)
  if manifest.mason.lsp_servers then
    table.insert(specs, {
      "mason-org/mason-lspconfig.nvim",
      opts = {
        -- Don't auto-install, let mason-tool-installer handle it
        automatic_installation = false,
      },
    })
  end

  -- Add mason-tool-installer for automatic installation in headless mode
  -- This is the ONLY place we specify ensure_installed to avoid conflicts
  table.insert(specs, {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    opts = {
      ensure_installed = mason_packages,
      auto_update = false,
      run_on_start = true,
    },
  })
end

return specs
LOADER_EOF

# Add manifest loader to LazyVim config
cat >> ~/.config/nvim/lua/config/lazy.lua << 'LAZY_EOF'

-- Load plugins from manifest
vim.env.MANIFEST_PATH = os.getenv("MANIFEST_PATH") or "/workspace/config/plugin-manifest.lua"

-- Disable LazyVim's automatic Mason installs (we handle it via mason-tool-installer)
vim.g.lazyvim_mason_auto_install = false
LAZY_EOF

# Create plugin file that loads manifest
cat > ~/.config/nvim/lua/plugins/from-manifest.lua << 'PLUGIN_EOF'
-- Auto-generated from plugin-manifest.lua
return require("config.manifest-loader")
PLUGIN_EOF

echo "✅ Config generated"
echo ""

# Step 4: Install all LazyVim plugins
echo "📦 Step 4: Installing LazyVim plugins..."
export MANIFEST_PATH="$MANIFEST"

if nvim --headless "+Lazy! sync" +qa; then
  echo "✅ LazyVim plugins installed"
else
  echo "❌ LazyVim plugin installation failed"
  exit 1
fi
echo ""

# Step 5: Install Mason packages via mason-tool-installer
{ set +x; } 2>/dev/null  # Temporarily disable command echoing for cleaner output
echo ""
echo "🔧 Step 5: Installing Mason packages..."
echo "Using mason-tool-installer (MasonToolsInstallSync is synchronous)..."
echo ""
echo "Running: nvim --headless -c \"MasonToolsInstallSync\" +qa"
echo ""
set -x  # Re-enable command echoing

# Start Neovim and run MasonToolsInstallSync
# MasonToolsInstallSync is synchronous and will block until all packages are installed
# Then +qa quits when the command finishes
if nvim --headless -c "MasonToolsInstallSync" +qa 2>&1 | tee /tmp/mason-install.log; then
  { set +x; } 2>/dev/null
  echo ""
  echo "✅ Mason package installation completed"
  set -x
else
  EXIT_CODE=$?
  { set +x; } 2>/dev/null
  echo ""
  echo "⚠️  Mason installation exited with code $EXIT_CODE"
  echo "Check /tmp/mason-install.log for details"
  set -x
fi

{ set +x; } 2>/dev/null
echo ""
set -x

# Step 6: Verify installations
echo "=========================================="
echo "📊 Installation Summary"
echo "=========================================="

LAZY_DIR="$HOME/.local/share/nvim/lazy"
MASON_DIR="$HOME/.local/share/nvim/mason/packages"

if [ -d "$LAZY_DIR" ]; then
  PLUGIN_COUNT=$(find "$LAZY_DIR" -maxdepth 1 -type d 2>/dev/null | wc -l)
  PLUGIN_COUNT=$((PLUGIN_COUNT - 1))
  echo "✅ LazyVim plugins: $PLUGIN_COUNT installed"
  echo "   Location: $LAZY_DIR"
  echo "   Size: $(du -sh "$LAZY_DIR" 2>/dev/null | cut -f1)"
else
  echo "❌ No LazyVim plugins found"
fi

echo ""

if [ -d "$MASON_DIR" ]; then
  MASON_COUNT=$(find "$MASON_DIR" -maxdepth 1 -type d 2>/dev/null | wc -l)
  MASON_COUNT=$((MASON_COUNT - 1))
  echo "✅ Mason packages: $MASON_COUNT installed"
  echo "   Location: $MASON_DIR"
  echo "   Size: $(du -sh "$MASON_DIR" 2>/dev/null | cut -f1)"
else
  echo "❌ No Mason packages found"
fi

echo ""
echo "=========================================="
echo "✅ Installation Complete"
echo "=========================================="
