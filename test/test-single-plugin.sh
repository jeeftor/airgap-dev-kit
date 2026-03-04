#!/bin/bash
# Test Single Plugin Installation
# Install one plugin at a time to see if it's more reliable

set -e

echo "=========================================="
echo "🔧 Single Plugin Mason Test"
echo "=========================================="

# Backup existing files
echo "Step 1: Backing up existing Neovim files..."
mv ~/.config/nvim ~/.config/nvim.bak 2>/dev/null || true
mv ~/.local/share/nvim ~/.local/share/nvim.bak 2>/dev/null || true
echo "✓ Backed up existing files"

# Clone LazyVim starter
echo "Step 2: Setting up LazyVim starter..."
git clone https://github.com/LazyVim/starter ~/.config/nvim
rm -rf ~/.config/nvim/.git
echo "✓ Cloned LazyVim starter"

# Use production config
echo "Step 3: Using production config..."
cp /opt/test-configs/mason-config.lua ~/.config/nvim/init.lua

# Install plugins one at a time
echo "=========================================="
echo "📦 Installing Plugins One at a Time"
echo "=========================================="

PLUGINS=("lua-language-server" "bash-language-server" "vscode-langservers-extracted" "yaml-language-server" "marksman")

for plugin in "${PLUGINS[@]}"; do
    echo ""
    echo "🚀 Installing: $plugin"
    echo "Command: nvim --headless \"+Lazy! sync\" \":MasonInstall $plugin\" +qa"
    
    # Install single plugin
    if nvim --headless "+Lazy! sync" ":MasonInstall $plugin" +qa; then
        echo "✅ Successfully installed: $plugin"
    else
        echo "❌ Failed to install: $plugin"
    fi
    
    # Check if plugin was actually installed
    if [ -d "$HOME/.local/share/nvim/mason/packages/$plugin" ]; then
        echo "✅ Plugin directory exists: $plugin"
    else
        echo "❌ Plugin directory missing: $plugin"
    fi
done

# Final check
echo ""
echo "=========================================="
echo "Checking Final Installation Results"
echo "=========================================="

mason_dir="$HOME/.local/share/nvim/mason/packages"
if [ -d "$mason_dir" ]; then
    package_count=$(find "$mason_dir" -maxdepth 1 -type d | wc -l)
    package_count=$((package_count - 1))
    echo "✓ Found $package_count packages in $mason_dir"
    
    echo ""
    echo "All packages installed:"
    for package in "$mason_dir"/*; do
        if [ -d "$package" ]; then
            package_name=$(basename "$package")
            echo "  ✓ $package_name"
        fi
    done
    
    # Verify all expected plugins
    echo ""
    echo "Plugin verification:"
    for plugin in "${PLUGINS[@]}"; do
        if [ -d "$mason_dir/$plugin" ]; then
            echo "  ✅ $plugin"
        else
            echo "  ❌ $plugin (missing)"
        fi
    done
else
    echo "❌ Mason packages directory not found"
fi

echo ""
echo "=========================================="
echo "Single Plugin Test Complete"
echo "=========================================="
