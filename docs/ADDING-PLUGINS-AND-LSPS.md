# Adding Plugins and LSP Servers to Air-Gap Kit

This guide explains how to add new LazyVim plugins and LSP servers to your air-gap development environment.

## Understanding the Two Systems

### 1. LazyVim Plugins (managed by lazy.nvim)
- **What:** Editor features (UI, keymaps, utilities, themes, etc.)
- **Location:** `~/.local/share/nvim/lazy/`
- **Examples:** telescope, nvim-tree, which-key, colorschemes
- **Config:** `config/nvim/.config/nvim/lua/plugins/*.lua`

### 2. Mason Packages (managed by Mason)
- **What:** Language tools (LSP servers, formatters, linters, DAP adapters)
- **Location:** `~/.local/share/nvim/mason/packages/`
- **Examples:** lua-language-server, prettier, gopls, shellcheck
- **Config:** Same files, but different syntax

---

## Adding a New LazyVim Plugin

### Step 1: Add Plugin to Config

Create or edit a file in `config/nvim/.config/nvim/lua/plugins/`:

```lua
-- config/nvim/.config/nvim/lua/plugins/my-plugins.lua
return {
  -- Add a simple plugin
  {
    "folke/zen-mode.nvim",
    cmd = "ZenMode",  -- Lazy-load on command
    opts = {
      window = {
        width = 120,
      },
    },
  },

  -- Add a plugin with dependencies
  {
    "nvim-neo-tree/neo-tree.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      "MunifTanjim/nui.nvim",
    },
    opts = {
      -- Neo-tree config here
    },
  },
}
```

**See `config/nvim/.config/nvim/lua/plugins/example.lua` for more patterns!**

### Step 2: Test Installation Online

Before packaging for air-gap:

```bash
# In your dev environment (with internet)
nvim --headless "+Lazy! sync" +qa

# Check it installed
ls ~/.local/share/nvim/lazy/ | grep zen-mode
```

### Step 3: Package for Air-Gap

```bash
# Build and package all plugins
make test-package

# This creates: offline-packages/lazyvim-plugins.tar.gz
```

### Step 4: Deploy to Air-Gap Machine

```bash
# Extract plugins
tar -xzf lazyvim-plugins.tar.gz -C ~/.local/share/nvim/

# Copy config
cp -r airgap-dev-kit/config/nvim/.config/nvim ~/.config/
```

---

## Adding LSP Servers, Formatters, Linters

You already have `config/nvim/.config/nvim/lua/plugins/airgap-lsp.lua` that lists common tools.

### Step 1: Add to Your Config

Edit `config/nvim/.config/nvim/lua/plugins/airgap-lsp.lua`:

```lua
return {
  -- LSP Servers (use lspconfig names)
  {
    "mason-org/mason-lspconfig.nvim",
    opts = {
      ensure_installed = {
        "lua_ls",       -- Lua
        "pyright",      -- Python
        "gopls",        -- Go
        "rust_analyzer",-- Rust
        "clangd",       -- C/C++

        -- ADD NEW LSP SERVERS HERE:
        "html",         -- HTML
        "cssls",        -- CSS
        "dockerls",     -- Docker
      },
    },
  },

  -- Formatters/Linters (use Mason package names)
  {
    "mason-org/mason.nvim",
    opts = {
      ensure_installed = {
        "stylua",     -- Lua formatter
        "black",      -- Python formatter
        "prettier",   -- JS/TS/JSON/YAML formatter
        "shfmt",      -- Shell formatter

        -- ADD NEW TOOLS HERE:
        "markdownlint", -- Markdown linter
        "hadolint",     -- Dockerfile linter
        "sqlfluff",     -- SQL formatter/linter
      },
    },
  },
}
```

### Step 2: Find Mason Package Names

```bash
# Inside Docker or online machine:
nvim --headless "+lua print(vim.inspect(require('mason-registry').get_all_package_names()))" +qa

# Or search online:
# https://mason-registry.dev/registry/list
```

### Step 3: Test Installation

```bash
# Method 1: Via config (online machine)
nvim --headless "+Lazy! sync" +qa
nvim --headless "+MasonInstall lua-language-server prettier" +qa

# Method 2: Via Docker test
make test-interactive
# Then inside container:
nvim --headless "+MasonInstall rust-analyzer" +qa
ls ~/.local/share/nvim/mason/packages/
```

### Step 4: Package Mason Tools

```bash
# Install all Mason packages defined in your config
nvim --headless "+Lazy! sync" +qa
nvim --headless "+MasonInstallAll" +qa  # If you have this command

# Package them
cd ~/.local/share/nvim/mason
tar -czf mason-packages.tar.gz packages/

# On air-gap machine:
mkdir -p ~/.local/share/nvim/mason
tar -xzf mason-packages.tar.gz -C ~/.local/share/nvim/mason/
```

---

## Complete Air-Gap Workflow

### 1. Online Machine (Prepare)

```bash
# Add plugins to config/nvim/.config/nvim/lua/plugins/*.lua
# Add LSP servers to config/nvim/.config/nvim/lua/plugins/airgap-lsp.lua

# Install everything
nvim --headless "+Lazy! sync" +qa

# Package LazyVim plugins
make test-package  # Creates offline-packages/lazyvim-plugins.tar.gz

# Package Mason tools (manual for now)
cd ~/.local/share/nvim/mason
tar -czf ~/mason-packages.tar.gz packages/
```

### 2. Transfer to Air-Gap Machine

```bash
# Copy these files:
# - offline-packages/lazyvim-plugins.tar.gz
# - mason-packages.tar.gz
# - config/nvim/.config/nvim/
```

### 3. Air-Gap Machine (Install)

```bash
# Extract plugins
mkdir -p ~/.local/share/nvim
tar -xzf lazyvim-plugins.tar.gz -C ~/.local/share/nvim/

# Extract Mason tools
tar -xzf mason-packages.tar.gz -C ~/.local/share/nvim/mason/

# Copy config
cp -r config/nvim/.config/nvim ~/.config/

# Done! Launch Neovim
nvim
```

---

## Common Examples

### Example 1: Add Python Support

```lua
-- config/nvim/.config/nvim/lua/plugins/python.lua
return {
  -- LSP Server
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        pyright = {
          settings = {
            python = {
              analysis = {
                typeCheckingMode = "basic",
              },
            },
          },
        },
      },
    },
  },

  -- Ensure tools are installed
  {
    "mason-org/mason-lspconfig.nvim",
    opts = {
      ensure_installed = { "pyright" },
    },
  },
  {
    "mason-org/mason.nvim",
    opts = {
      ensure_installed = { "black", "isort", "flake8" },
    },
  },
}
```

### Example 2: Add a New Colorscheme

```lua
-- config/nvim/.config/nvim/lua/plugins/theme.lua
return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "catppuccin",
    },
  },
}
```

### Example 3: Add Rust Support

```lua
-- config/nvim/.config/nvim/lua/plugins/rust.lua
return {
  {
    "mason-org/mason-lspconfig.nvim",
    opts = {
      ensure_installed = { "rust_analyzer" },
    },
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        rust_analyzer = {
          settings = {
            ["rust-analyzer"] = {
              cargo = {
                allFeatures = true,
              },
            },
          },
        },
      },
    },
  },
}
```

---

## Troubleshooting

### Plugin Not Loading?

```bash
# Check if plugin is installed
ls ~/.local/share/nvim/lazy/ | grep plugin-name

# Check lazy.nvim logs
nvim
:Lazy log
```

### LSP Server Not Working?

```bash
# Check if Mason package is installed
ls ~/.local/share/nvim/mason/packages/ | grep language-server

# Check LSP status in Neovim
:LspInfo
:Mason
```

### Need to Find Mason Package Names?

Visit: https://mason-registry.dev/registry/list

Or run:
```bash
nvim --headless "+lua print(vim.inspect(require('mason-registry').get_all_package_names()))" +qa
```

---

## Key Differences

| Feature | LazyVim Plugins | Mason Packages |
|---------|----------------|----------------|
| **What** | Editor features | Language tools |
| **Location** | `~/.local/share/nvim/lazy/` | `~/.local/share/nvim/mason/packages/` |
| **Config Location** | `lua/plugins/*.lua` | Same files, different sections |
| **Config Syntax** | `{ "author/plugin" }` | `ensure_installed = { "tool-name" }` |
| **Name Format** | GitHub `owner/repo` | Mason registry name |
| **Install Command** | `nvim --headless "+Lazy! sync" +qa` | `nvim --headless "+MasonInstall tool" +qa` |

---

## Quick Reference

```bash
# Add plugin → Edit lua/plugins/*.lua → make test-package
# Add LSP → Edit lua/plugins/airgap-lsp.lua → Package mason/packages/

# Test online:
nvim --headless "+Lazy! sync" +qa

# Package for air-gap:
tar -czf lazyvim-plugins.tar.gz -C ~/.local/share/nvim lazy/
tar -czf mason-packages.tar.gz -C ~/.local/share/nvim/mason packages/

# Deploy to air-gap:
tar -xzf lazyvim-plugins.tar.gz -C ~/.local/share/nvim/
tar -xzf mason-packages.tar.gz -C ~/.local/share/nvim/mason/
```

---

## Next Steps

1. **Automate Mason packaging** - Add `make package-mason` target
2. **Version lock** - Pin plugin versions for stability
3. **Test matrix** - Test installation on fresh air-gap VM
4. **GitHub Actions** - Auto-build plugin packages on push
