-- Air-gap LSP configuration
-- Pre-install commonly used LSP servers for offline use
return {
  {
    "williamboman/mason.nvim",
    opts = {
      -- Essential LSP servers to pre-install for air-gap environments
      ensure_installed = {
        -- Language servers
        "lua-language-server",      -- Lua
        "pyright",                   -- Python
        "typescript-language-server", -- TypeScript/JavaScript
        "bash-language-server",      -- Bash
        "json-lsp",                  -- JSON
        "yaml-language-server",      -- YAML
        "gopls",                     -- Go
        "rust-analyzer",             -- Rust
        "clangd",                    -- C/C++

        -- Formatters
        "stylua",                    -- Lua formatter
        "black",                     -- Python formatter
        "prettier",                  -- JS/TS/JSON/YAML formatter
        "shfmt",                     -- Shell formatter

        -- Linters
        "shellcheck",                -- Shell linter
        "eslint_d",                  -- JS/TS linter
        "pylint",                    -- Python linter
      },
    },
  },
}
