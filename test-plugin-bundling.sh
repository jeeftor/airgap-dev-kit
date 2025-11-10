#!/usr/bin/env bash
# Test script for Neovim plugin bundling (simulates GitHub Actions)

set -e

echo "🧪 Testing Neovim plugin bundling locally..."
echo ""

# Simulate GITHUB_WORKSPACE
GITHUB_WORKSPACE="$PWD"

# Clean up any previous test runs
rm -rf /tmp/nvim-plugin-test
mkdir -p /tmp/nvim-plugin-test
cd /tmp/nvim-plugin-test

echo "📦 Extracting Neovim binary..."
tar -xzf "$GITHUB_WORKSPACE/offline-packages/linux/nvim-linux64.tar.gz"

# Set NVIM to the extracted binary path
NVIM="$PWD/nvim-linux-x86_64/bin/nvim"

echo "✓ Neovim extracted to: $NVIM"
echo ""

# Verify Neovim is working
echo "🔍 Verifying Neovim..."
$NVIM --version
echo ""

# Set up Neovim config from repo
echo "📝 Setting up Neovim config..."
mkdir -p ~/.config/nvim-test
if [[ -d "$GITHUB_WORKSPACE/config/.config/nvim" ]]; then
  cp -r "$GITHUB_WORKSPACE/config/.config/nvim"/* ~/.config/nvim-test/
  echo "✓ Neovim config copied from repo"
else
  echo "❌ No Neovim config found in config/.config/nvim/"
  exit 1
fi
echo ""

# Install plugins using lazy.nvim (headless mode)
echo "🔌 Installing Neovim plugins with lazy.nvim..."
echo "   This may take a few minutes on first run..."
XDG_CONFIG_HOME="$HOME/.config/nvim-test" \
XDG_DATA_HOME="/tmp/nvim-plugin-test/data" \
  $NVIM --headless "+Lazy! sync" +qa

echo ""

# Verify plugins were installed
if [[ -d /tmp/nvim-plugin-test/data/nvim/lazy ]]; then
  echo "✓ Plugins installed successfully:"
  ls -la /tmp/nvim-plugin-test/data/nvim/lazy/ | head -10
  echo "   ... (showing first 10)"
  echo ""
  echo "📊 Total plugins installed: $(ls -1 /tmp/nvim-plugin-test/data/nvim/lazy/ | wc -l)"
else
  echo "❌ No plugins directory found"
  exit 1
fi
echo ""

# Bundle plugins into tarball
echo "📦 Bundling plugins..."
cd /tmp/nvim-plugin-test/data/nvim
tar -czf lazy-plugins.tar.gz lazy/ lazy-lock.json 2>/dev/null || tar -czf lazy-plugins.tar.gz lazy/

echo "✓ Plugins bundled to: lazy-plugins.tar.gz"
ls -lh lazy-plugins.tar.gz
echo ""

# Show what would be in the bundle
echo "📋 Plugin bundle contents:"
tar -tzf lazy-plugins.tar.gz | head -20
echo "   ... (showing first 20 files)"
echo ""

echo "✅ Test completed successfully!"
echo ""
echo "To clean up test files, run:"
echo "  rm -rf /tmp/nvim-plugin-test ~/.config/nvim-test"
