# Test Directory - LazyVim Plugin Packaging

This directory contains everything needed to test and package LazyVim plugins for air-gap deployment.

## 📚 Documentation

| File | Purpose |
|------|---------|
| **../docs/QUICK-START-DRY.md** | ⭐ Start here! DRY workflow (recommended) |
| **../docs/DRY-WORKFLOW.md** | Complete DRY guide (single source of truth) |
| **SIMPLE.md** | Simple 3-command approach (legacy) |
| **COMMANDS.md** | Copy-paste command reference |
| **TESTING.md** | Detailed testing documentation |
| **../docs/ADDING-PLUGINS-AND-LSPS.md** | How to add plugins and LSP servers |

## 🚀 Quick Start

### DRY Workflow (Recommended)

```bash
# 1. Edit the manifest
vim config/plugin-manifest.lua

# 2. Test locally
make test-manifest

# 3. Package for production
make test-package-manifest
```

### Legacy Workflow

```bash
# Test plugin installation
make test

# Package for air-gap
make test-package

# Interactive testing
make test-interactive
```

## 📁 Files

- `test-config-based.sh` - Main test script (installs LazyVim plugins)
- `test-mason.sh` - Mason LSP installation test (multiple modes)
- `test-mason.Dockerfile` - Docker environment with Neovim + dependencies
- `scripts/` - Helper scripts for test setup
- `lib/` - Common test utilities

## 🎯 What Gets Packaged?

### LazyVim Plugins
- **Location:** `~/.local/share/nvim/lazy/`
- **Install:** `nvim --headless "+Lazy! sync" +qa`
- **Package:** Created by `make test-package`
- **Output:** `offline-packages/lazyvim-plugins.tar.gz`

### Mason Packages (LSP/Formatters)
- **Location:** `~/.local/share/nvim/mason/packages/`
- **Install:** `nvim --headless "+MasonInstall <package>" +qa`
- **Package:** Manual: `tar -czf mason-packages.tar.gz -C ~/.local/share/nvim/mason packages/`
- **TODO:** Add `make package-mason` target

## 🔧 Common Tasks

### Test Plugin Installation
```bash
make test
# Or manually:
docker run --rm -v $(pwd):/workspace airgap-mason-test bash /workspace/test/test-config-based.sh
```

### Package Plugins
```bash
make test-package
# Creates: offline-packages/lazyvim-plugins.tar.gz
```

### Debug Interactively
```bash
make test-interactive
# Inside container, see COMMANDS.md for what to run
```

### Test Mason Packages
```bash
# Single plugin mode
docker run --rm -v $(pwd):/workspace airgap-mason-test bash /workspace/test/test-mason.sh single lua-language-server

# GitHub workflow mode
make test-github
```

## 🐳 Docker Image

The `test-mason.Dockerfile` creates an Ubuntu 24.04 image with:
- Neovim v0.11.2 (built from source)
- Git, curl, wget
- ripgrep, fd, fzf
- Node.js, npm
- Build tools (cmake, ninja, etc.)
- Lazygit
- Test scripts in `/opt/test-scripts/`

**Why build from source?** System Neovim doesn't have the latest features LazyVim needs.

**Why not use static binary?** Testing needs full Neovim with runtime files and Lua modules.

## 🏗️ Build & Test Flow

```
1. Edit config files
   ↓
2. Run make test (installs plugins in Docker)
   ↓
3. Run make test-package (extracts plugins to tarball)
   ↓
4. Transfer tarball to air-gap machine
   ↓
5. Extract and use!
```

## 📝 Adding New Plugins

See `docs/ADDING-PLUGINS-AND-LSPS.md` for details.

**Quick version:**
1. Edit `config/nvim/.config/nvim/lua/plugins/my-plugins.lua`
2. Add: `{ "author/plugin-name" }`
3. Run: `make test-package`
4. Done!

## 🔍 Troubleshooting

### Docker build fails?
```bash
# Force rebuild without cache
make test-rebuild
```

### Plugins not installing?
```bash
# Check Neovim version
docker run --rm airgap-mason-test nvim --version

# Check logs
docker run --rm -it airgap-mason-test bash
cat ~/.local/state/nvim/lazy.log
```

### Need to test manually?
```bash
make test-interactive
# Then follow commands in COMMANDS.md
```

## 🎓 Key Concepts

### Two Separate Systems

1. **LazyVim Plugins** (lazy.nvim)
   - Editor features, UI, utilities
   - Managed by `lazy.nvim`
   - Config: `lua/plugins/*.lua`
   - Syntax: `{ "author/repo" }`

2. **Mason Packages** (Mason)
   - LSP servers, formatters, linters
   - Managed by Mason
   - Config: Same files, different section
   - Syntax: `ensure_installed = { "package-name" }`

### Air-Gap Mode

Your config has:
```lua
install = {
  missing = false,  -- Don't download plugins
}
```

This tells LazyVim to use pre-installed plugins only.

## 🚧 TODO

- [ ] Add `make package-mason` target
- [ ] Automate Mason package bundling
- [ ] Add version pinning for plugins
- [ ] Create GitHub Action for auto-packaging
- [ ] Add verification script for air-gap machine

## 📖 Further Reading

- LazyVim docs: https://www.lazyvim.org
- lazy.nvim docs: https://lazy.folke.io
- Mason docs: https://github.com/williamboman/mason.nvim
- Mason package list: https://mason-registry.dev/registry/list
