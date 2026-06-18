-- Air-gap LSP configuration
-- Pre-install commonly used LSP servers for offline use
return {
  -- Configure mason-lspconfig to ensure LSP servers are installed
  {
    "mason-org/mason-lspconfig.nvim",
    opts = {
      -- Use lspconfig server names (not Mason package names)
      ensure_installed = {
        "lua_ls",       -- Lua
        "pyright",      -- Python
        "ts_ls",        -- TypeScript/JavaScript (renamed from tsserver)
        "bashls",       -- Bash
        "jsonls",       -- JSON
        "yamlls",       -- YAML
        "gopls",        -- Go
        "rust_analyzer",-- Rust
        "clangd",       -- C/C++
      },
    },
  },

  -- Configure mason.nvim to ensure formatters/linters are installed
  {
    "mason-org/mason.nvim",
    opts = {
      -- Use Mason package names for non-LSP tools
      ensure_installed = {
        -- Formatters
        "stylua",     -- Lua formatter
        "black",      -- Python formatter
        "prettier",   -- JS/TS/JSON/YAML formatter
        "shfmt",      -- Shell formatter

        -- Linters
        "shellcheck", -- Shell linter
        "eslint_d",   -- JS/TS linter
        "flake8",     -- Python linter (simpler than pylint)
      },
    },
  },
}
