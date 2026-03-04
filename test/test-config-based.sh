#!/bin/bash
# Simple LazyVim Plugin Installation Test
# This script installs LazyVim plugins and packages them for air-gap deployment

set -e

echo "=========================================="
echo "🚀 LazyVim Plugin Installation Test"
echo "=========================================="
echo ""

# Step 1: Clean slate
echo "📦 Step 1: Clean existing Neovim config..."
rm -rf ~/.config/nvim ~/.local/share/nvim ~/.local/state/nvim ~/.cache/nvim
echo "✅ Clean slate ready"
echo ""

# Step 2: Clone LazyVim starter
echo "📦 Step 2: Clone LazyVim starter config..."
git clone --depth 1 https://github.com/LazyVim/starter ~/.config/nvim
rm -rf ~/.config/nvim/.git
echo "✅ LazyVim starter cloned"
echo ""

# Step 3: Install plugins headlessly
echo "📦 Step 3: Installing all LazyVim plugins..."
echo "Command: nvim --headless \"+Lazy! sync\" +qa"
echo ""

if nvim --headless "+Lazy! sync" +qa; then
    echo ""
    echo "✅ Plugin installation completed"
else
    echo ""
    echo "❌ Plugin installation failed"
    exit 1
fi
echo ""

# Step 4: Verify installation
echo "=========================================="
echo "📊 Installation Results"
echo "=========================================="
echo ""

LAZY_DIR="$HOME/.local/share/nvim/lazy"
MASON_DIR="$HOME/.local/share/nvim/mason/packages"

if [ -d "$LAZY_DIR" ]; then
    PLUGIN_COUNT=$(find "$LAZY_DIR" -maxdepth 1 -type d | wc -l)
    PLUGIN_COUNT=$((PLUGIN_COUNT - 1))
    echo "✅ LazyVim plugins installed: $PLUGIN_COUNT"
    echo ""
    echo "📁 Plugins in $LAZY_DIR:"
    ls -1 "$LAZY_DIR" | head -20

    if [ $PLUGIN_COUNT -gt 20 ]; then
        echo "   ... and $((PLUGIN_COUNT - 20)) more"
    fi
else
    echo "❌ No plugins found at $LAZY_DIR"
    exit 1
fi

echo ""
echo "=========================================="
echo "📦 Packaging Information"
echo "=========================================="
echo ""

# Calculate sizes
LAZY_SIZE=$(du -sh "$LAZY_DIR" 2>/dev/null | cut -f1)
echo "LazyVim plugins size: $LAZY_SIZE"
echo "Location: $LAZY_DIR"
echo ""

echo "To package these plugins for air-gap deployment:"
echo "  tar -czf lazyvim-plugins.tar.gz -C ~/.local/share/nvim lazy"
echo ""

echo "To extract on air-gapped machine:"
echo "  tar -xzf lazyvim-plugins.tar.gz -C ~/.local/share/nvim"
echo ""

echo "=========================================="
echo "✅ Test Complete"
echo "=========================================="
