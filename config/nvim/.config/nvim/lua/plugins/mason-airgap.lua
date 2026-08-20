-- Mason LSP Server Management for Air-Gap Kit
-- This config uses Mason to manage LSP servers offline

return {
  -- Mason configuration for offline LSP server management
  {
    "mason-org/mason.nvim",
    opts = {
      -- The bundled payload includes the builder's registry cache. Do not try
      -- to refresh it on an air-gapped target.
      registry_cache = {
        refresh = false,
      },
      PATH = "prepend",
      max_concurrent_installers = 5,
    },
    init = function()
      local node_bin = vim.fn.stdpath("data") .. "/mason/node/bin"
      if vim.fn.isdirectory(node_bin) == 1 then
        vim.env.PATH = node_bin .. ":" .. vim.env.PATH
      end
    end,
  },

  -- Mason-lspconfig bridge (ensure_installed belongs here, not in nvim-lspconfig)
  -- Full LSP server list is in airgap-lsp.lua; gopls server settings are in go.lua
  {
    "mason-org/mason-lspconfig.nvim",
    dependencies = {
      "mason-org/mason.nvim",
      "neovim/nvim-lspconfig",
    },
  },

  -- Air-gap Mason setup helper
  {
    "LazyVim/LazyVim",
    opts = function(_, opts)
      vim.api.nvim_create_user_command("MasonAirGapStatus", function()
        local packages = { "gopls", "bash-language-server", "lua-language-server" }
        local root = vim.fn.stdpath("data") .. "/mason/packages/"
        for _, package in ipairs(packages) do
          if vim.fn.isdirectory(root .. package) == 1 then
            print("✓ " .. package .. " (bundled)")
          else
            print("✗ " .. package .. " (missing from bundled payload)")
          end
        end
      end, { desc = "Show bundled air-gap Mason package status" })
    end,
  },
}
