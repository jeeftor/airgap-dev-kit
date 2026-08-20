-- Plugin Manifest - Single Source of Truth
-- This file is used by:
--   1. Local Docker testing (test/test-config-based.sh)
--   2. GitHub Actions workflows
--   3. Final air-gap package builds
--
-- Edit this file to customize which plugins get bundled

return {
  -- LazyVim Plugins (will be in ~/.local/share/nvim/lazy/)
  plugins = {
    -- Core LazyVim (always included)
    core = {
      "LazyVim/LazyVim",
      "folke/lazy.nvim",
    },

    -- Additional plugins you want in the air-gap kit
    extras = {
      -- Themes/Colorschemes
      "tanvirtin/monokai.nvim",       -- Monokai theme
      "folke/tokyonight.nvim",        -- Tokyo Night theme

      -- UI enhancements
      "folke/zen-mode.nvim",
      "folke/twilight.nvim",

      -- Git
      "lewis6991/gitsigns.nvim",
      "sindrets/diffview.nvim",

      -- File navigation
      "nvim-neo-tree/neo-tree.nvim",
      "nvim-telescope/telescope.nvim",

      -- Productivity
      "folke/which-key.nvim",
      "folke/trouble.nvim",

      -- Add your custom plugins here:
      -- "author/plugin-name",
    },
  },

  -- Mason Packages (LSP servers, formatters, linters)
  -- IMPORTANT: Use Mason package names, not lspconfig names!
  -- See: https://mason-registry.dev/registry/list
  mason = {
    -- LSP Servers (use Mason package names!)
    lsp_servers = {
      "lua-language-server",      -- Lua (lspconfig: lua_ls)
      "bash-language-server",     -- Bash (lspconfig: bashls)
      "json-lsp",                 -- JSON (lspconfig: jsonls)
      "yaml-language-server",     -- YAML (lspconfig: yamlls)
      "marksman",                 -- Markdown
      "pyright",                  -- Python
      "rust-analyzer",            -- Rust (lspconfig: rust_analyzer)
      "typescript-language-server", -- TypeScript/JavaScript (lspconfig: ts_ls)

      "gopls",                   -- Go
      -- "clangd",                -- C/C++ (needs C++ compiler)

      -- Add more LSP servers here:
      -- "html-lsp",
      -- "css-lsp",
      -- "dockerfile-language-server",
    },

    -- Formatters
    formatters = {
      "stylua",           -- Lua
      "prettier",         -- JS/TS/JSON/YAML/etc
      "shfmt",            -- Shell

      -- Requires compilers/interpreters:
      -- "black",         -- Python (needs Python build tools)
      -- "gofumpt",       -- Go (needs Go compiler)
      -- "rustfmt",       -- Rust (needs Rust compiler)

      -- Add more formatters here:
      -- "clang-format",
    },

    -- Linters
    linters = {
      "shellcheck",       -- Shell
      "eslint_d",         -- JS/TS

      -- Requires interpreters:
      -- "flake8",        -- Python (needs Python)
      -- "hadolint",      -- Dockerfile
      -- "markdownlint",
    },
  },

  -- LazyVim Extras (language packs)
  -- These are LazyVim's official language/feature modules
  -- See: https://www.lazyvim.org/extras
  lazyvim_extras = {
    -- Languages
    "lazyvim.plugins.extras.lang.go",
    "lazyvim.plugins.extras.lang.python",
    "lazyvim.plugins.extras.lang.json",
    "lazyvim.plugins.extras.lang.yaml",
    "lazyvim.plugins.extras.lang.markdown",
    "lazyvim.plugins.extras.lang.rust",
    "lazyvim.plugins.extras.lang.docker",

    -- Add more language packs:
    -- "lazyvim.plugins.extras.lang.typescript",
    -- "lazyvim.plugins.extras.lang.clangd",

    -- Features
    -- "lazyvim.plugins.extras.coding.copilot",  -- Skip for air-gap
    -- "lazyvim.plugins.extras.ui.mini-starter",
  },
}
