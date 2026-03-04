#!/bin/bash
# Common utility functions for Mason/LazyVim tests

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored status messages
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Print section header
print_section() {
    echo ""
    echo "=========================================="
    echo "$1"
    echo "=========================================="
}

# Setup Neovim test environment
setup_nvim_env() {
    local app_name="$1"
    local config_dir="$HOME/.config/$app_name"
    
    print_info "Setting up Neovim environment for $app_name..."
    
    # Create config directory
    mkdir -p "$config_dir"
    cd "$config_dir"
    
    print_success "Created config directory: $config_dir"
}

# Clone lazy.nvim if not present
clone_lazy_nvim() {
    if [[ ! -d "lazy" ]]; then
        print_info "Cloning lazy.nvim..."
        git clone --filter=blob:none https://github.com/folke/lazy.nvim.git --branch=stable lazy >/dev/null 2>&1
        print_success "lazy.nvim cloned"
    else
        print_success "lazy.nvim already exists"
    fi
}

# Copy mounted config file
copy_config() {
    local config_file="$1"
    local target_name="${2:-init.lua}"
    
    if [[ -f "/workspace/test/configs/$config_file" ]]; then
        cp "/workspace/test/configs/$config_file" "$target_name"
        print_success "Copied $config_file to $target_name"
    else
        print_error "Config file not found: /workspace/test/configs/$config_file"
        exit 1
    fi
}

# Run Neovim with headless mode
run_nvim_headless() {
    local app_name="$1"
    local commands="$2"
    
    print_info "Running headless mode: nvim --headless '$commands' +qa"
    NVIM_APPNAME="$app_name" nvim --headless "$commands" +qa
}

# Check Mason installation results
check_mason_results() {
    local app_name="$1"
    local show_binaries="${2:-false}"
    
    local mason_dir="$HOME/.local/share/$app_name/mason/packages"
    
    print_section "Checking Mason Installation"
    
    if [[ -d "$mason_dir" ]]; then
        local count=$(ls -1 "$mason_dir" | wc -l)
        print_success "Found $count packages in $mason_dir"
        
        if [[ $count -gt 0 ]]; then
            echo ""
            echo "Installed packages:"
            ls -1 "$mason_dir"
            
            if [[ "$show_binaries" == "true" ]]; then
                echo ""
                echo "Checking binaries..."
                find "$mason_dir" -name "*language-server" -type f -executable 2>/dev/null | head -5
            fi
        fi
    else
        print_error "No Mason installation found"
        return 1
    fi
}

# Check LazyVim plugins
check_lazyvim_plugins() {
    print_section "Checking LazyVim Plugins"
    
    if [[ -d "$HOME/.local/share/nvim/lazy" ]]; then
        local plugin_count=$(ls -1 "$HOME/.local/share/nvim/lazy" | wc -l)
        print_success "Found $plugin_count LazyVim plugins"
        
        echo ""
        echo "Key plugins:"
        local key_plugins=("LazyVim" "mason.nvim" "nvim-treesitter" "telescope.nvim" "which-key.nvim")
        for plugin in "${key_plugins[@]}"; do
            if [[ -d "$HOME/.local/share/nvim/lazy/$plugin" ]]; then
                print_success "$plugin"
            else
                print_error "$plugin"
            fi
        done
    else
        print_error "No plugins directory found"
    fi
}

# Backup existing Neovim files
backup_nvim_files() {
    print_info "Backing up existing Neovim files..."
    
    for dir in ~/.config/nvim ~/.local/share/nvim ~/.local/state/nvim ~/.cache/nvim; do
        if [[ -d "$dir" ]]; then
            mv "$dir" "$dir.bak"
            print_success "Backed up $dir"
        fi
    done
}

# Clone LazyVim starter
clone_lazyvim_starter() {
    print_info "Cloning LazyVim starter..."
    git clone https://github.com/LazyVim/starter ~/.config/nvim >/dev/null 2>&1
    print_success "Cloned LazyVim starter"
    
    print_info "Removing .git folder..."
    rm -rf ~/.config/nvim/.git
    print_success "Removed .git folder"
}

# Run health check
run_health_check() {
    print_info "Running LazyHealth check..."
    
    # Create health check script
    cat > /tmp/health_check.lua <<'EOF'
vim.defer_fn(function()
  vim.cmd('LazyHealth')
  vim.defer_fn(function() vim.cmd('qa') end, 3000)
end, 1000)
EOF
    
    nvim --headless -c "luafile /tmp/health_check.lua" 2>/dev/null || true
}

# Print test completion
print_test_complete() {
    local test_name="$1"
    print_section "$test_name Complete"
}
