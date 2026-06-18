# DRY Workflow - Single Source of Truth

This document explains the **Don't Repeat Yourself (DRY)** approach for managing plugins and LSP servers.

## Problem We Solved

**Before:** Plugin lists were scattered across:
- Test scripts
- Docker configs
- GitHub workflows
- Manual commands

**After:** One file controls everything: **`config/plugin-manifest.lua`**

## The DRY Solution

### 🎯 Single Source of Truth: `config/plugin-manifest.lua`

This file defines ALL plugins and tools. It's used by:
1. ✅ Local Docker testing
2. ✅ GitHub Actions builds
3. ✅ Production packages
4. ✅ Air-gap deployments

### 📂 Architecture

```
config/plugin-manifest.lua          ← Edit this to add plugins!
         ↓
scripts/install-from-manifest.sh    ← Reads manifest, installs everything
         ↓
    ┌────┴────┐
    ↓         ↓
Docker Test   GitHub Actions
(make test)   (.github/workflows/)
    ↓         ↓
    └────┬────┘
         ↓
offline-packages/
  - lazyvim-plugins-manifest.tar.gz
  - mason-packages-manifest.tar.gz
```

## Quick Start

### 1. Add Plugins to Manifest

Edit `config/plugin-manifest.lua`:

```lua
return {
  plugins = {
    extras = {
      "folke/zen-mode.nvim",     -- Add a new plugin!
      "folke/twilight.nvim",
    },
  },

  mason = {
    lsp_servers = {
      "lua_ls",
      "rust_analyzer",           -- Add a new LSP!
    },
    formatters = {
      "stylua",
      "rustfmt",                -- Add a new formatter!
    },
  },
}
```

### 2. Test Locally

```bash
# Test the manifest works
make test-manifest

# Package everything
make test-package-manifest
```

### 3. Deploy to GitHub Actions

```bash
git add config/plugin-manifest.lua
git commit -m "Add Rust support"
git push
```

GitHub Actions will automatically:
- Read your manifest
- Install all plugins
- Create packages
- Upload artifacts

### 4. Use in Air-Gap

```bash
# Download from GitHub Actions artifacts
# Or use locally built packages

tar -xzf lazyvim-plugins-manifest.tar.gz -C ~/.local/share/nvim/
tar -xzf mason-packages-manifest.tar.gz -C ~/.local/share/nvim/mason/
```

## Commands Reference

### Local Testing

```bash
# Test with manifest (recommended)
make test-manifest

# Package from manifest (production-ready)
make test-package-manifest

# Interactive testing with manifest
docker run --rm -it \
  -v $(pwd):/workspace \
  -e MANIFEST_PATH=/workspace/config/plugin-manifest.lua \
  airgap-mason-test bash

# Inside container:
/workspace/scripts/install-from-manifest.sh
```

### GitHub Actions

Workflow: `.github/workflows/build-nvim-packages.yml`

**Triggers automatically on:**
- Push to main (if `config/plugin-manifest.lua` changed)
- Weekly schedule (Sunday at midnight UTC)
- Manual dispatch

**Creates artifacts:**
- `lazyvim-plugins.tar.gz`
- `mason-packages.tar.gz`
- `MANIFEST.txt` (lists all installed packages)

### Manual Script Usage

```bash
# Run the installer script directly
./scripts/install-from-manifest.sh /path/to/manifest.lua

# Use environment variable
export MANIFEST_PATH=/custom/path/plugin-manifest.lua
./scripts/install-from-manifest.sh
```

## What Gets Installed?

The manifest defines three categories:

### 1. LazyVim Plugins

```lua
plugins = {
  extras = {
    "author/plugin-name",  -- GitHub repo format
  }
}
```

**Installed to:** `~/.local/share/nvim/lazy/`

### 2. Mason Packages

```lua
mason = {
  lsp_servers = { "lua_ls", "gopls" },
  formatters = { "stylua", "prettier" },
  linters = { "shellcheck", "eslint_d" },
}
```

**Installed to:** `~/.local/share/nvim/mason/packages/`

### 3. LazyVim Extras (Language Packs)

```lua
lazyvim_extras = {
  "lazyvim.plugins.extras.lang.go",
  "lazyvim.plugins.extras.lang.python",
}
```

**These are LazyVim's official modules** that bundle plugins + LSP + config.

See: https://www.lazyvim.org/extras

## Benefits of This Approach

### ✅ DRY (Don't Repeat Yourself)
- One file controls everything
- No duplicate plugin lists
- Change once, works everywhere

### ✅ Testable
- Test locally before pushing
- Same code in test and production
- Predictable results

### ✅ Maintainable
- Easy to add/remove plugins
- Clear structure
- Self-documenting

### ✅ Shareable
- Fork the repo, edit manifest, done
- Team can collaborate on plugin list
- Version control tracks changes

### ✅ Automatable
- GitHub Actions builds packages automatically
- Weekly updates possible
- No manual intervention needed

## File Structure

```
airgap-dev-kit/
├── config/
│   └── plugin-manifest.lua           ← EDIT THIS (single source of truth)
├── scripts/
│   └── install-from-manifest.sh      ← Installation logic
├── test/
│   └── test-with-manifest.sh         ← Test wrapper
├── .github/
│   └── workflows/
│       └── build-nvim-packages.yml   ← GitHub Actions
└── Makefile                          ← Convenient commands
```

## Common Workflows

### Workflow 1: Add New Language Support

```bash
# 1. Edit manifest
vim config/plugin-manifest.lua
# Add to lazyvim_extras: "lazyvim.plugins.extras.lang.rust"
# Add to lsp_servers: "rust_analyzer"
# Add to formatters: "rustfmt"

# 2. Test locally
make test-manifest

# 3. Package
make test-package-manifest

# 4. Push to GitHub
git add config/plugin-manifest.lua
git commit -m "Add Rust support"
git push
```

### Workflow 2: Add Custom Plugin

```bash
# 1. Edit manifest
vim config/plugin-manifest.lua
# Add to plugins.extras: "folke/zen-mode.nvim"

# 2. Test
make test-manifest

# 3. Package
make test-package-manifest
```

### Workflow 3: Customize for Your Team

```bash
# 1. Fork repo
# 2. Edit config/plugin-manifest.lua
# 3. Push changes
# 4. GitHub Actions builds your custom package
# 5. Download from Actions artifacts
# 6. Distribute to team
```

## Comparison: Old vs New

### Old Approach (scattered)
```bash
# Edit test script
vim test/test-mason.sh
# Add plugin: "lua-language-server"

# Edit GitHub workflow
vim .github/workflows/build.yml
# Add plugin: "lua-language-server"

# Edit production config
vim config/nvim/.config/nvim/lua/plugins/airgap-lsp.lua
# Add plugin: "lua_ls"

# Three files to keep in sync! 😱
```

### New Approach (DRY)
```bash
# Edit ONE file
vim config/plugin-manifest.lua
# Add: lsp_servers = { "lua_ls" }

# Works everywhere! 🎉
make test-manifest              # Local test
make test-package-manifest      # Package
git push                        # GitHub Actions
```

## Extending the Manifest

The manifest is just a Lua table. You can add more fields:

```lua
return {
  plugins = { ... },
  mason = { ... },
  lazyvim_extras = { ... },

  -- Custom additions
  metadata = {
    version = "1.0.0",
    description = "My company's air-gap dev kit",
    maintainer = "team@company.com",
  },

  -- Custom config
  settings = {
    theme = "tokyonight",
    tab_width = 2,
  },
}
```

Then update `scripts/install-from-manifest.sh` to use these fields.

## Troubleshooting

### Manifest not found?
```bash
# Check path
ls -la config/plugin-manifest.lua

# Set explicit path
export MANIFEST_PATH=/full/path/to/manifest.lua
make test-manifest
```

### Plugin not installing?
```bash
# Check manifest syntax
lua -e "dofile('config/plugin-manifest.lua')"

# Run with verbose output
docker run --rm -it -v $(pwd):/workspace airgap-mason-test bash
/workspace/scripts/install-from-manifest.sh
```

### GitHub Actions not triggering?
Check workflow paths in `.github/workflows/build-nvim-packages.yml`:
```yaml
paths:
  - 'config/plugin-manifest.lua'  # Must match your file
```

## Next Steps

1. **Edit** `config/plugin-manifest.lua` to customize plugins
2. **Test** with `make test-manifest`
3. **Package** with `make test-package-manifest`
4. **Push** to GitHub for automated builds
5. **Download** artifacts from GitHub Actions
6. **Deploy** to air-gapped machines

## Philosophy

> "Make it easy to do the right thing."

By having a single source of truth:
- Reduces errors
- Simplifies maintenance
- Enables automation
- Improves collaboration
- Makes the system predictable

Edit one file, everything else follows.
