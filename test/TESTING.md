# Local Testing with Docker

Test LazyVim plugin installations locally without pushing to GitHub.

## Documentation

- **SIMPLE.md** - Quick 3-command approach to package plugins
- **COMMANDS.md** - Copy-paste command reference
- **../docs/ADDING-PLUGINS-AND-LSPS.md** - Complete guide to adding plugins and LSP servers

## Quick Start (Simplest)

### Test LazyVim Plugin Installation

```bash
# 1. Test plugin installation (recommended)
make test

# 2. Package plugins for air-gap deployment
make test-package

# 3. Interactive testing for debugging
make test-interactive
```

## Manual Testing (Step-by-Step)

Want to test manually inside Docker? Here's the exact commands:

### Start Interactive Container

```bash
# Build image (if not already built)
docker build -f test/test-mason.Dockerfile -t airgap-mason-test .

# Start interactive shell
docker run --rm -it -v $(pwd):/workspace airgap-mason-test bash
```

### Inside Container - LazyVim Plugin Installation

```bash
# Clean slate
rm -rf ~/.config/nvim ~/.local/share/nvim ~/.local/state/nvim ~/.cache/nvim

# Clone LazyVim starter
git clone --depth 1 https://github.com/LazyVim/starter ~/.config/nvim
rm -rf ~/.config/nvim/.git

# Install all plugins
nvim --headless "+Lazy! sync" +qa

# Check results
ls -la ~/.local/share/nvim/lazy
```

### Inside Container - Package Plugins

```bash
# After installation above, package the plugins
cd ~/.local/share/nvim
tar -czf /workspace/lazyvim-plugins.tar.gz lazy/

# Check size
du -h /workspace/lazyvim-plugins.tar.gz
```

### On Host - Extract Packaged Plugins

```bash
# The tarball is now in your workspace
ls -lh lazyvim-plugins.tar.gz

# To install on air-gapped machine:
mkdir -p ~/.local/share/nvim
tar -xzf lazyvim-plugins.tar.gz -C ~/.local/share/nvim
```

## Test Structure

```
test/
├── lib/                    # Common utilities and functions
│   └── common.sh          # Reusable test functions
├── configs/               # Reusable Neovim configs (mounted into containers)
│   ├── mason-basic.lua    # Basic Mason test config
│   ├── mason-working.lua  # Advanced Mason with monitoring
│   └── lazyvim-mason.lua  # LazyVim MasonInstallAll command
├── *.Dockerfile          # Docker images for testing
│   ├── test-mason.Dockerfile      # System Neovim with all prerequisites
│   └── test-mason-static.Dockerfile # Static Neovim for production testing
├── test-*.sh             # Original test scripts (detailed)
├── test-*-simple.sh       # Simplified tests using common functions
├── run-tests.sh          # Test runner for multiple tests
└── TESTING.md            # This documentation
```

## Simplified Testing (Recommended)

We've created common utility functions to eliminate code duplication. Use the simplified tests for faster development:

### Simplified Test Scripts
- `test-mason-basic-simple.sh` - Basic Mason test using common functions
- `test-mason-working-simple.sh` - Working Mason test using common functions  
- `test-lazyvim-simple.sh` - LazyVim test using common functions

### Test Runner
- `run-tests.sh` - Run multiple tests with summary reporting

**Benefits:**
- ✅ **DRY Principle** - Common functions eliminate duplication
- ✅ **Consistent Output** - Standardized colors and formatting
- ✅ **Easier Maintenance** - Changes to common logic affect all tests
- ✅ **Better Error Handling** - Centralized error reporting
- ✅ **Quick Iteration** - Simplified scripts are easier to modify

### Usage Examples:

```bash
# Run all simplified tests
./run-tests.sh

# Run specific tests
./run-tests.sh test-mason-basic-simple.sh test-lazyvim-simple.sh

# Run with verbose output
./run-tests.sh --verbose

# Dry run to see what would be executed
./run-tests.sh --dry-run

# Run individual simplified test
./test-mason-basic-simple.sh
```

## Test Scripts

### `test-mason-basic.sh`
Simple Mason test with minimal setup:
- Uses mounted `configs/mason-basic.lua`
- Tests basic Mason installation
- Installs lua-language-server as test

**Use this to debug:**
- Basic Mason functionality
- lazy.nvim bootstrap issues
- Neovim version compatibility

### `test-mason-working.sh`
Step-by-step Mason test:
- Uses mounted `configs/mason-working.lua`
- Tests Mason registry loading
- Attempts multiple package installations
- Directory monitoring for completion detection
- Shows detailed progress and results

**Use this to debug:**
- Mason registry loading issues
- Package installation timing
- Multiple package handling
- Async installation completion

### `test-lazyvim-headless.sh`
Full LazyVim installation using headless commands:
- Clones official LazyVim starter
- Uses mounted `configs/lazyvim-mason.lua`
- Runs `nvim --headless '+Lazy install' +MasonInstallAll +qall`
- Tests complete LazyVim + Mason setup

**Use this to verify:**
- LazyVim plugin installation works
- MasonInstallAll command functionality
- Headless mode operations
- Complete development environment setup

### `test-mason-fswatch.sh`
Experimental directory monitoring test:
- Attempts to use fswatch for monitoring
- Alternative to async waiting approaches

**Use this to experiment:**
- Directory monitoring techniques
- Alternative completion detection

## Config Files

### `configs/mason-basic.lua`
Minimal Mason configuration for basic testing:
- Simple Mason setup
- Basic package installation test
- No complex monitoring

### `configs/mason-working.lua`
Advanced Mason configuration with monitoring:
- Directory stability checking
- Timeout protection
- Multiple package installation
- Progress feedback

### `configs/lazyvim-mason.lua`
LazyVim-compatible Mason command:
- MasonInstallAll user command
- Comprehensive tool list
- Synchronous installation with timeouts
- Designed for LazyVim integration

## Interactive Debugging

```bash
# Start container with shell
docker run --rm -it -v $(pwd):/workspace airgap-mason-test bash

# Inside container, you can:
nvim --version                          # Verify Neovim
bash /workspace/test/test-mason-basic.sh    # Run basic Mason test
bash /workspace/test/test-mason-working.sh   # Run working Mason test
bash /workspace/test/test-lazyvim-headless.sh # Run LazyVim test

# Or manually test commands:
NVIM_APPNAME=nvim-test nvim --headless "+Lazy! sync" +qa
ls -la ~/.local/share/nvim-test/

# Check Mason registry manually:
nvim --headless -c "lua print(vim.inspect(require('mason-registry').get_all_package_names()))" +qa
```

## Iterate Faster

Instead of pushing to GitHub and waiting for Actions:

1. **Edit config files** - Modify files in `test/configs/`
2. **Run in Docker** - Use `make test` or individual test scripts
3. **See results immediately** - No GitHub Actions delay
4. **Debug interactively** - Drop into container shell to experiment

## Headless Mode Benefits

Our tests now use LazyVim's built-in headless commands:

- `nvim --headless '+Lazy install' +qa` - Install plugins
- `nvim --headless '+Lazy install' +MasonInstallAll +qall` - Install plugins + Mason tools
- `nvim --headless ':LazyHealth' +qa` - Run health checks

**Benefits:**
- Proper plugin loading sequence
- Built-in async handling
- No complex directory monitoring needed
- Follows LazyVim best practices

## Common Issues to Debug

### Mason Registry Not Loading
**Symptom:** All packages show "Not found"
**Test:** Run `test-mason-basic.sh` and check registry loading
**Fix ideas:**
- Check lazy.nvim installation
- Verify network access in container
- Ensure proper Neovim runtime files

### Async Installation Not Completing
**Symptom:** Installation starts but doesn't finish
**Test:** Run `test-mason-working.sh` with directory monitoring
**Fix ideas:**
- Use headless mode commands instead
- Check timeout values
- Verify Mason package names

### LazyVim Plugin Issues
**Symptom:** Plugins don't load or install
**Test:** Run `test-lazyvim-headless.sh`
**Fix ideas:**
- Check LazyVim starter clone
- Verify MasonInstallAll command
- Run `:LazyHealth` for diagnostics

## Neovim Testing vs Production

### Testing Environment
- **Uses:** System Neovim from Ubuntu repositories (v0.9.5)
- **Runtime files:** Full system installation with all runtime files
- **Binary:** System `/usr/bin/nvim` (Ubuntu package)
- **Why:** Mason/LazyVim need runtime files and Lua modules

### Production Air-Gap Kit
- **Uses:** Static Neovim binary from `jeeftor/static-neovim`
- **Why:** Self-contained, no system dependencies, perfect for air-gap
- **Location:** `offline-packages/linux/nvim-static-x86_64`

### Why Different Approaches?
- **Testing needs:** Runtime files, Lua modules, plugin loading compatibility
- **Production needs:** Portability, air-gap compatibility, no dependencies
- **Trade-off:** Different binaries for different environments
- **Note:** Mason packages work across both environments

## Files

- `test/test-mason.Dockerfile` - Docker image with system Neovim and all prerequisites
- `test/test-mason-static.Dockerfile` - Docker image with static Neovim for production testing
- `test/configs/` - Reusable Neovim configuration files
- `test/test-*.sh` - Test scripts using mounted configs
- `Makefile` - Contains `make test`, `make test-interactive`, `make test-rebuild`
- `test/TESTING.md` - This file
