-- Mason LSP Server Management for Air-Gap Kit
-- This config uses Mason to manage LSP servers offline

return {
  -- Mason configuration for offline LSP server management
  {
    "williamboman/mason.nvim",
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

  -- Mason LSP configuration
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "williamboman/mason-lspconfig.nvim",
    },
    opts = {
      -- Ensure LSP servers are installed (from local Mason registry)
      ensure_installed = {
        "gopls",
        -- Add more servers as needed:
        -- "pyright",
        -- "clangd", 
        -- "rust_analyzer",
        -- "lua_ls",
        -- "bashls",
      },
      -- Configure servers with custom paths for air-gap
      servers = {
        gopls = {
          -- Use gopls from our air-gap package if available
          cmd = { "./offline-packages/linux/gopls" },
          -- Fallback to Mason if our package doesn't have it
          cmd = function()
            if vim.fn.executable("./offline-packages/linux/gopls") == 1 then
              return { "./offline-packages/linux/gopls" }
            else
              return { "gopls" }
            end
          end,
          settings = {
            gopls = {
              gofumpt = true,
              staticcheck = true,
              analyses = {
                unusedparams = true,
                shadow = true,
                unusedwrite = true,
                useany = true,
                fillreturns = true,
                nonews = true,
                noresultvalues = true,
                undeclaredname = true,
                fillstruct = true,
              },
              hints = {
                assignVariableTypes = true,
                compositeLiteralFields = true,
                constantValues = true,
                functionTypeParameters = true,
                parameterNames = true,
                rangeVariableTypes = true,
              },
              buildFlags = { "-tags", "integration" },
              usePlaceholders = true,
              completeUnimported = true,
              deepCompletion = true,
              ui.diagnostic.staticcheck = true,
              experimentalPostfixCompletions = true,
              experimentalWorkspaceModule = true,
            },
          },
        },
      },
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
