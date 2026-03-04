#!/bin/bash
# Unified Mason LSP Installation Script
# Works for both local testing and GitHub Actions
#
# Usage:
#   ./install-mason-lsp.sh                    # Default: install test packages
#   ./install-mason-lsp.sh --production       # Install production packages
#   ./install-mason-lsp.sh --watch            # Watch installation progress
#   ./install-mason-lsp.sh --timeout 300      # Custom timeout in seconds

set -e

# Configuration
TIMEOUT=${2:-120}  # Default 2 minutes
WATCH_MODE=false
PRODUCTION_MODE=false
NVIM_APPNAME=${NVIM_APPNAME:-nvim-test}

# Parse arguments
case "$1" in
    --watch)
        WATCH_MODE=true
        ;;
    --production)
        PRODUCTION_MODE=true
        ;;
    --timeout)
        TIMEOUT="$2"
        ;;
    --help)
        echo "Usage: $0 [--watch|--production|--timeout SECONDS]"
        echo ""
        echo "Options:"
        echo "  --watch        Watch installation progress in real-time"
        echo "  --production  Install production LSP packages"
        echo "  --timeout N    Set timeout to N seconds (default: 120)"
        echo ""
        echo "Environment variables:"
        echo "  NVIM_APPNAME   Neovim config directory (default: nvim-test)"
        exit 0
        ;;
esac

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================"
echo -e "🔧 Mason LSP Installation Script"
echo -e "========================================${NC}"
echo ""

# Determine packages to install
if [ "$PRODUCTION_MODE" = true ]; then
    echo -e "${YELLOW}📦 Production mode: Installing full LSP suite${NC}"
    PACKAGES=(
        "gopls"
        "lua-language-server" 
        "pyright"
        "bash-language-server"
        "json-lsp"
        "yaml-language-server"
        "marksman"
        "tailwindcss-language-server"
        "typescript-language-server"
        "css-lsp"
    )
    TIMEOUT=${2:-300}  # 5 minutes for production
else
    echo -e "${YELLOW}🧪 Test mode: Installing test packages${NC}"
    PACKAGES=(
        "lua-language-server"
        "gopls"
    )
fi

echo -e "${BLUE}📋 Packages to install:${NC}"
for pkg in "${PACKAGES[@]}"; do
    echo "  • $pkg"
done
echo ""

# Setup directories
CONFIG_DIR="$HOME/.config/$NVIM_APPNAME"
MASON_DIR="$HOME/.local/share/$NVIM_APPNAME/mason"

echo -e "${BLUE}🗂️  Setup:${NC}"
echo "  Config dir: $CONFIG_DIR"
echo "  Mason dir:  $MASON_DIR"
echo "  Timeout:    ${TIMEOUT}s"
echo ""

# Create minimal Neovim config for Mason
echo -e "${BLUE}🔧 Creating minimal Neovim config...${NC}"
mkdir -p "$CONFIG_DIR"

cat > "$CONFIG_DIR/init.lua" << 'EOF'
-- Minimal Mason configuration for headless installation
vim.opt.runtimepath:prepend(vim.fn.stdpath('data') .. '/lazy/lazy.nvim')

-- Setup lazy.nvim
require('lazy').setup({
  {
    'williamboman/mason.nvim',
    config = function()
      require('mason').setup({
        ui = {
          border = 'none',
        }
      })
      
      -- Install packages after Mason is ready
      local mason_registry = require('mason-registry')
      local packages = {}
      
      -- Get package list from environment or use defaults
      local package_list = vim.env.MASON_PACKAGES or "lua-language-server,gopls"
      
      for pkg in string.gmatch(package_list, '([^,]+)') do
        table.insert(packages, pkg)
      end
      
      vim.defer_fn(function()
        print("=== Installing " .. #packages .. " packages ===")
        
        local installed = 0
        local total = #packages
        
        for _, pkg_name in ipairs(packages) do
          local ok, pkg = pcall(mason_registry.get_package, pkg_name)
          if ok then
            print("Installing " .. pkg_name .. "...")
            pkg:install():once(function()
              installed = installed + 1
              print("✓ " .. pkg_name .. " installed (" .. installed .. "/" .. total .. ")")
              
              if installed == total then
                print("=== All packages installed ===")
                vim.defer_fn(function()
                  vim.cmd('qa')
                end, 1000)
              end
            end)
          else
            print("❌ Package not found: " .. pkg_name)
            installed = installed + 1
          end
        end
      end, 2000)  -- Wait 2 seconds for Mason to initialize
    end,
  },
})

-- Auto-exit after timeout to prevent hanging
vim.defer_fn(function()
  print("=== Timeout reached, exiting ===")
  vim.cmd('qa')
end, tonumber(vim.env.MASON_TIMEOUT or '120000'))  -- Default 2 minutes
EOF

# Export package list for Neovim
export MASON_PACKAGES=$(IFS=,; echo "${PACKAGES[*]}")
export MASON_TIMEOUT=$((TIMEOUT * 1000))  # Convert to milliseconds

echo -e "${BLUE}🚀 Starting Mason installation...${NC}"
echo ""

# Watch mode: monitor directories in real-time
if [ "$WATCH_MODE" = true ]; then
    echo -e "${YELLOW}👀 Watch mode: Monitoring installation progress${NC}"
    echo ""
    
    # Start Neovim in background
    timeout "${TIMEOUT}s" nvim --headless \
        --cmd "lua require('lazy').sync()" \
        +qa &
    NVIM_PID=$!
    
    # Watch Mason directory
    echo -e "${BLUE}📦 Watching Mason packages directory:${NC}"
    watch -n 2 "ls -la '$MASON_DIR/packages/' 2>/dev/null || echo 'No packages yet...'" &
    WATCH_PID=$!
    
    # Wait for Neovim to complete
    wait $NVIM_PID
    kill $WATCH_PID 2>/dev/null || true
    
    echo ""
    echo -e "${BLUE}✅ Installation completed${NC}"
else
    # Normal mode: run with timeout
    echo -e "${BLUE}⏱️  Running with ${TIMEOUT}s timeout...${NC}"
    
    if timeout "${TIMEOUT}s" nvim --headless \
        --cmd "lua require('lazy').sync()" \
        +qa; then
        echo -e "${GREEN}✅ Installation completed successfully${NC}"
    else
        echo -e "${YELLOW}⚠️  Installation timed out after ${TIMEOUT}s${NC}"
    fi
fi

# Check results
echo ""
echo -e "${BLUE}========================================"
echo -e "📊 Installation Results"
echo -e "========================================${NC}"

if [ -d "$MASON_DIR/packages" ]; then
    echo -e "${GREEN}✅ Mason packages directory exists${NC}"
    
    # List installed packages
    echo ""
    echo -e "${BLUE}📦 Installed packages:${NC}"
    if [ "$(ls -A "$MASON_DIR/packages")" ]; then
        for pkg_dir in "$MASON_DIR/packages"/*; do
            if [ -d "$pkg_dir" ]; then
                pkg_name=$(basename "$pkg_dir")
                echo -e "  ${GREEN}✓${NC} $pkg_name"
                
                # Check for binaries
                if [ -d "$pkg_dir/bin" ]; then
                    for binary in "$pkg_dir/bin"/*; do
                        if [ -f "$binary" ]; then
                            echo "    └─ $(basename "$binary")"
                        fi
                    done
                fi
            fi
        done
    else
        echo -e "  ${YELLOW}⚠️  No packages found${NC}"
    fi
else
    echo -e "${RED}❌ Mason packages directory not found${NC}"
    echo -e "${RED}   Expected: $MASON_DIR/packages${NC}"
fi

echo ""
echo -e "${BLUE}🗂️  Mason directory structure:${NC}"
if [ -d "$MASON_DIR" ]; then
    find "$MASON_DIR" -type d -maxdepth 3 | sort
else
    echo -e "${RED}❌ Mason directory not found${NC}"
fi

echo ""
echo -e "${BLUE}========================================"
echo -e "${GREEN}🎯 Script completed${NC}"
echo -e "========================================${NC}"
