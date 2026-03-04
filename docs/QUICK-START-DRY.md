# Quick Start: DRY Workflow

## TL;DR

**One file controls everything:** `config/plugin-manifest.lua`

```bash
# 1. Edit plugins
vim config/plugin-manifest.lua

# 2. Test locally
make test-manifest

# 3. Package for production
make test-package-manifest

# 4. Done!
```

## Add a Plugin (5 seconds)

Edit `config/plugin-manifest.lua`:

```lua
return {
  plugins = {
    extras = {
      "folke/zen-mode.nvim",  -- ← Add this line!
    },
  },
}
```

Run: `make test-manifest`

## Add an LSP Server (5 seconds)

Edit `config/plugin-manifest.lua`:

```lua
return {
  mason = {
    lsp_servers = {
      "rust_analyzer",  -- ← Add this line!
    },
  },
}
```

Run: `make test-manifest`

## Add a Language Pack (5 seconds)

Edit `config/plugin-manifest.lua`:

```lua
return {
  lazyvim_extras = {
    "lazyvim.plugins.extras.lang.rust",  -- ← Add this line!
  },
}
```

Run: `make test-manifest`

## Commands

```bash
# Test it works
make test-manifest

# Package for production
make test-package-manifest

# Interactive debugging
make test-interactive
# Inside: /workspace/scripts/install-from-manifest.sh

# Check what's installed
make test-manifest
# Look for "Installation Summary" at the end
```

## What You Get

After `make test-package-manifest`:

```
offline-packages/
├── lazyvim-plugins-manifest.tar.gz   ← LazyVim plugins
└── mason-packages-manifest.tar.gz    ← LSP servers, formatters, linters
```

## Install on Air-Gap Machine

```bash
tar -xzf lazyvim-plugins-manifest.tar.gz -C ~/.local/share/nvim/
tar -xzf mason-packages-manifest.tar.gz -C ~/.local/share/nvim/mason/
cp -r config/.config/nvim ~/.config/
```

## Benefits

✅ Edit ONE file instead of many
✅ Works in Docker, GitHub Actions, production
✅ Easy to customize
✅ Easy to share
✅ Version controlled

## Full Docs

- `docs/DRY-WORKFLOW.md` - Complete guide
- `docs/ADDING-PLUGINS-AND-LSPS.md` - Plugin details
- `test/SIMPLE.md` - Basic approach
- `test/COMMANDS.md` - Command reference

## Example: Add Python Support

```lua
-- config/plugin-manifest.lua
return {
  lazyvim_extras = {
    "lazyvim.plugins.extras.lang.python",  -- Language pack
  },
  mason = {
    lsp_servers = {
      "pyright",          -- LSP
    },
    formatters = {
      "black", "isort",   -- Formatters
    },
    linters = {
      "flake8",           -- Linter
    },
  },
}
```

```bash
make test-manifest           # Test
make test-package-manifest   # Package
# Done! Python support bundled.
```

## GitHub Actions

Push `config/plugin-manifest.lua` to GitHub:
- Automatically builds packages
- Uploads as artifacts
- Weekly updates (optional)

No manual work needed!

## Philosophy

**Before:** Edit 5 files, keep them in sync
**After:** Edit 1 file, everything follows

That's DRY.
