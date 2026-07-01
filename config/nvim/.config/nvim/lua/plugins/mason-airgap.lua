-- Mason LSP Server Management for Air-Gap Kit
-- This config uses Mason to manage LSP servers offline

return {
  -- Mason configuration for offline LSP server management
  {
    "mason-org/mason.nvim",
    opts = {
      -- For air-gap: disable network calls
      registries = {
        github = {
          download_url_template = "file:///path/to/mason-registry/%s",
        },
      },
      -- Use local registry for air-gap
      max_concurrent_installers = 5,
      -- Disable automatic updates for air-gap stability
      automatic_installation = false,
    },
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
      -- Add air-gap Mason commands
      vim.api.nvim_create_user_command("MasonAirGapInstall", function()
        -- Install from our packaged Mason registry
        require("mason-registry").install_all()
      end, { desc = "Install LSP servers from air-gap package" })

      vim.api.nvim_create_user_command("MasonAirGapStatus", function()
        -- Show status of air-gap LSP servers
        local servers = { "gopls" }
        for _, server in ipairs(servers) do
          local path = "./offline-packages/linux/" .. server
          if vim.fn.executable(path) == 1 then
            print("✓ " .. server .. " (air-gap package)")
          elseif vim.fn.executable(server) == 1 then
            print("✓ " .. server .. " (system)")
          else
            print("✗ " .. server .. " (not found)")
          end
        end
      end, { desc = "Show air-gap LSP server status" })
    end,
  },
}
