-- Minimal Neovim config for Mason automation
-- Used by GitHub Actions to install LSP servers in headless mode

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none", 
    "https://github.com/folke/lazy.nvim.git", 
    "--branch=stable", 
    lazypath
  })
end
vim.opt.rtp:prepend(lazypath)

-- Setup Mason only
require("lazy").setup({
  { "williamboman/mason.nvim" },
  { "williamboman/mason-lspconfig.nvim" },
}, {
  defaults = {
    lazy = false,
  },
})

-- Mason configuration for air-gap builds
require("mason").setup({
  ui = {
    border = "single",
  },
  -- Disable registry fetch for air-gap builds
  registries = {
    github = "mason-org/mason-registry",
  },
  max_concurrent_installers = 5,
})

-- Auto-install essential LSP servers for air-gap kit
require("mason-lspconfig").setup({
  ensure_installed = {
    -- Essential servers for air-gap development
    "gopls",          -- Go language server
    "lua_ls",         -- Lua (for Neovim config)
    "bashls",         -- Shell scripting
    "jsonls",         -- JSON files
    "yamlls",         -- YAML files
    "marksman",       -- Markdown
    -- Future servers (commented out for now):
    -- "pyright",      -- Python
    -- "clangd",       -- C/C++
    -- "rust_analyzer", -- Rust
    -- "tsserver",     -- TypeScript/JavaScript
    -- "html",         -- HTML
    -- "cssls",        -- CSS
    -- "dockerls",     -- Docker
    -- "terraformls",  -- Terraform
    -- "sqlls",        -- SQL
    -- "taplo",        -- TOML
  },
  automatic_installation = false, -- We'll install manually in workflow
})
