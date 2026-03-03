#!/bin/bash
# Test LazyVim plugin installation with your actual config
# Run this in Docker to test what GitHub Actions does

set -e

echo "=========================================="
echo "Testing LazyVim Plugin Installation"
echo "=========================================="

# Copy your actual config
if [[ -d /workspace/config/.config/nvim ]]; then
  echo "Copying LazyVim config from repo..."
  mkdir -p ~/.config/nvim
  cp -r /workspace/config/.config/nvim/* ~/.config/nvim/

  # Enable plugin installation (override air-gap setting)
  if [[ -f ~/.config/nvim/lua/config/lazy.lua ]]; then
    sed -i 's/missing = false/missing = true/' ~/.config/nvim/lua/config/lazy.lua
    echo "✓ Enabled plugin installation"
  fi
else
  echo "⚠ No config found in /workspace/config/.config/nvim"
  exit 1
fi

echo ""
echo "Installing LazyVim plugins..."
nvim --headless "+Lazy! sync" +qa

echo ""
echo "Checking installed plugins..."
if [[ -d ~/.local/share/nvim/lazy ]]; then
  PLUGIN_COUNT=$(ls -1 ~/.local/share/nvim/lazy | wc -l)
  echo "✓ Found $PLUGIN_COUNT plugins installed"
  echo ""
  echo "Plugins:"
  ls -1 ~/.local/share/nvim/lazy
else
  echo "⚠ No plugins directory found"
fi

echo ""
echo "Checking Mason packages (from LazyVim)..."
if [[ -d ~/.local/share/nvim/mason/packages ]]; then
  MASON_COUNT=$(ls -1 ~/.local/share/nvim/mason/packages | wc -l)
  echo "✓ Found $MASON_COUNT Mason packages"
  echo ""
  echo "Mason packages:"
  ls -1 ~/.local/share/nvim/mason/packages
else
  echo "⚠ No Mason packages installed by LazyVim"
fi

echo ""
echo "=========================================="
echo "LazyVim Test Complete"
echo "=========================================="
