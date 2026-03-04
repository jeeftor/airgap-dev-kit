#!/bin/bash
# Clean Mason Installation Test
# Supports different installation modes with DRY principles

set -e

# Usage
usage() {
    echo "Usage: $0 <mode>"
    echo ""
    echo "Modes:"
    echo "  single <plugins...>    - Install plugins one at a time"
    echo "  batch <plugins...>      - Install all plugins in one command"
    echo "  github                 - Use GitHub workflow packages"
    echo "  standard               - Install standard packages"
    echo ""
    echo "Examples:"
    echo "  $0 single lua-language-server bash-language-server"
    echo "  $0 batch shfmt stylua prettier"
    echo "  $0 github"
    echo "  $0 standard"
    exit 1
}

# Parse arguments
MODE="$1"
shift || true

if [ -z "$MODE" ]; then
    usage
fi

echo "=========================================="
echo "🧪 Mason Installation Test"
echo "Mode: $MODE"
echo "=========================================="

# Common setup
setup_env() {
    echo "Step 1: Backing up existing Neovim files..."
    mv ~/.config/nvim ~/.config/nvim.bak 2>/dev/null || true
    mv ~/.local/share/nvim ~/.local/share/nvim.bak 2>/dev/null || true
    echo "✓ Backed up existing files"

    echo "Step 2: Setting up LazyVim starter..."
    git clone https://github.com/LazyVim/starter ~/.config/nvim
    rm -rf ~/.config/nvim/.git
    echo "✓ Cloned LazyVim starter"

    echo "Step 3: Using production config..."
    cp /opt/test-configs/mason-dev-config.lua ~/.config/nvim/init.lua
    echo "✓ Dev config loaded (network access enabled)"
}

# Install plugins one at a time
install_single() {
    local plugins=("$@")
    echo "=========================================="
    echo "📦 Installing Plugins One at a Time"
    echo "Plugins: ${plugins[*]}"
    echo "=========================================="

    # Create Mason directory structure
    echo "🔧 Creating Mason directory structure..."
    mkdir -p "$HOME/.local/share/nvim/mason/packages"
    echo "✅ Mason directories created"

    # Initialize Mason first
    echo "🔧 Installing Mason plugins..."
    local install_cmd="nvim --headless \"+Lazy install mason.nvim mason-lspconfig.nvim\" +qa"
    echo "Command: $install_cmd"
    
    if eval "$install_cmd"; then
        echo "✅ Mason plugins installed"
    else
        echo "❌ Mason plugins installation failed"
    fi

    echo "🔧 Initializing Mason..."
    local init_cmd="nvim --headless \"+Lazy! sync\" \":Mason\" +qa"
    echo "Command: $init_cmd"
    
    if eval "$init_cmd"; then
        echo "✅ Mason initialized"
    else
        echo "❌ Mason initialization failed"
    fi

    # Run debug info
    echo ""
    echo "🔍 Running Mason debug..."
    local mason_debug_cmd="nvim --headless \":lua require('mason').setup({ui={border='single'}}); require('mason.log').open()\" +qa"
    echo "Command: $mason_debug_cmd"
    eval "$mason_debug_cmd"

    # Check Mason registry
    echo ""
    echo "🔍 Checking Mason registry..."
    local registry_cmd="nvim --headless \":lua local reg = require('mason-registry'); print('Registry available:', reg ~= nil)\" +qa"
    echo "Command: $registry_cmd"
    eval "$registry_cmd"

    for plugin in "${plugins[@]}"; do
        echo ""
        echo "🚀 Installing: $plugin"
        
        # Pre-install file snapshot
        echo "📸 Taking pre-install snapshot..."
        find "$HOME" -type f -name "*$plugin*" 2>/dev/null | sort > "/tmp/pre_install_$plugin.txt"
        find "$HOME/.local/share/nvim/mason" -type f 2>/dev/null | sort >> "/tmp/pre_install_$plugin.txt"
        
        local cmd="nvim --headless \"+Lazy! sync\" \":MasonInstall $plugin\" \"sleep 5\" +qa"
        echo "Command: $cmd"
        
        if eval "$cmd"; then
            echo "✅ Successfully installed: $plugin"
        else
            echo "❌ Failed to install: $plugin"
        fi
        
        # Post-install file snapshot
        echo "📸 Taking post-install snapshot..."
        find "$HOME" -type f -name "*$plugin*" 2>/dev/null | sort > "/tmp/post_install_$plugin.txt"
        find "$HOME/.local/share/nvim/mason" -type f 2>/dev/null | sort >> "/tmp/post_install_$plugin.txt"
        
        # Show diff
        echo ""
        echo "🔍 File system changes for $plugin:"
        if diff "/tmp/pre_install_$plugin.txt" "/tmp/post_install_$plugin.txt"; then
            echo "❌ No file changes detected"
        else
            echo "✅ File changes detected (shown above)"
        fi
        
        # Check if plugin was actually installed
        if [ -d "$HOME/.local/share/nvim/mason/packages/$plugin" ]; then
            echo "✅ Plugin directory exists: $plugin"
            echo "📁 Plugin contents:"
            find "$HOME/.local/share/nvim/mason/packages/$plugin" -type f 2>/dev/null | head -10
        else
            echo "❌ Plugin directory missing: $plugin"
        fi
        
        # Cleanup temp files
        rm -f "/tmp/pre_install_$plugin.txt" "/tmp/post_install_$plugin.txt"
    done
}

# Install all plugins in one command
install_batch() {
    local plugins=("$@")
    echo "=========================================="
    echo "📦 Installing Plugins in Batch"
    echo "Plugins: ${plugins[*]}"
    echo "=========================================="

    # Build command
    local cmd="nvim --headless \"+Lazy! sync\""
    for plugin in "${plugins[@]}"; do
        cmd="$cmd \":MasonInstall $plugin\""
    done
    cmd="$cmd +qa"

    echo "🚀 Running command:"
    echo "$cmd"
    echo ""

    if eval "$cmd"; then
        echo "✅ Batch installation completed"
    else
        echo "❌ Batch installation failed"
    fi
}

# GitHub workflow mode
github_mode() {
    echo "=========================================="
    echo "🐙 GitHub Workflow Mode"
    echo "=========================================="
    
    local plugins=("lua-language-server" "bash-language-server" "vscode-langservers-extracted" "yaml-language-server" "marksman")
    install_batch "${plugins[@]}"
}

# Standard packages mode
standard_mode() {
    echo "=========================================="
    echo "📦 Standard Packages Mode"
    echo "=========================================="
    
    local plugins=("shfmt" "stylua" "prettier" "eslint_d" "black")
    install_batch "${plugins[@]}"
}

# Check results
check_results() {
    echo ""
    echo "=========================================="
    echo "Checking Installation Results"
    echo "=========================================="

    echo "🔍 Debugging: Checking possible Mason locations..."
    echo "HOME: $HOME"
    echo "XDG_DATA_HOME: ${XDG_DATA_HOME:-<not set>}"
    
    # Check standard location
    local mason_dir="$HOME/.local/share/nvim/mason/packages"
    echo "Checking standard location: $mason_dir"
    if [ -d "$mason_dir" ]; then
        local package_count=$(find "$mason_dir" -maxdepth 1 -type d | wc -l)
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
    else
        echo "❌ Standard Mason packages directory not found"
        
        # Check if parent directories exist
        echo "🔍 Checking parent directories:"
        echo "  ~/.local/share: $([ -d "$HOME/.local/share" ] && echo "exists" || echo "missing")"
        echo "  ~/.local/share/nvim: $([ -d "$HOME/.local/share/nvim" ] && echo "exists" || echo "missing")"
        echo "  ~/.local/share/nvim/mason: $([ -d "$HOME/.local/share/nvim/mason" ] && echo "exists" || echo "missing")"
        
        # Check for any mason directories
        echo ""
        echo "🔍 Searching for any mason directories:"
        find "$HOME" -type d -name "*mason*" 2>/dev/null | head -5
        
        # Check for any package directories
        echo ""
        echo "🔍 Searching for any Mason packages:"
        find "$HOME" -type d -name "*language-server*" 2>/dev/null | head -5
        find "$HOME" -type d -name "*lua-language-server*" 2>/dev/null | head -5
    fi
}

# Main execution
setup_env

case "$MODE" in
    "single")
        if [ $# -eq 0 ]; then
            echo "Error: single mode requires plugins"
            usage
        fi
        install_single "$@"
        ;;
    "batch")
        if [ $# -eq 0 ]; then
            echo "Error: batch mode requires plugins"
            usage
        fi
        install_batch "$@"
        ;;
    "github")
        github_mode
        ;;
    "standard")
        standard_mode
        ;;
    *)
        echo "Error: Unknown mode: $MODE"
        usage
        ;;
esac

check_results

echo ""
echo "=========================================="
echo "Mason Test Complete"
echo "=========================================="
