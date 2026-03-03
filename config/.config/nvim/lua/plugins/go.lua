-- Go LSP configuration with gopls
-- This config enables Go language server support when gopls is available
-- Based on official gopls documentation: https://go.dev/gopls/editor/vim.md

return {
  -- Configure gopls LSP server
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        gopls = {
          -- Only enable gopls if the binary is available
          enabled = function()
            return vim.fn.executable("gopls") == 1
          end,
          settings = {
            gopls = {
              -- General settings (from official docs)
              gofumpt = true,
              codelenses = {
                generate = true, -- Enable code generation lenses
                gc_details = true, -- Show garbage collection details
                tidy = true, -- Enable go mod tidy lens
                upgrade_dependency = true, -- Enable dependency upgrade lens
                regenerate_cgo = true, -- Enable cgo regeneration lens
              },
              hints = {
                assignVariableTypes = true,
                compositeLiteralFields = true,
                constantValues = true,
                functionTypeParameters = true,
                parameterNames = true,
                rangeVariableTypes = true,
              },
              -- Build settings
              buildFlags = { "-tags", "integration" },
              -- Diagnostic settings (from official docs)
              staticcheck = true,
              analyses = {
                unusedparams = true, -- From official docs example
                shadow = true, -- Check for shadowed variables
                unusedwrite = true, -- Check for unused writes
                useany = true, -- Check for unnecessary use of any
                fillreturns = true, -- Suggest filling in return values
                nonews = true, -- Check for unnecessary new() calls
                noresultvalues = true, -- Check for functions with no result values
                undeclaredname = true, -- Check for undeclared names
                fillstruct = true, -- Suggest filling in struct fields
              },
              -- Completion settings
              usePlaceholders = true,
              -- Navigation settings
              completeUnimported = true,
              deepCompletion = true,
              -- Formatting
              ui.diagnostic.staticcheck = true,
              -- Experimental features
              experimentalPostfixCompletions = true,
              experimentalWorkspaceModule = true,
            },
          },
        },
      },
    },
  },

  -- Go-specific keymaps and commands
  {
    "LazyVim/LazyVim",
    opts = function(_, opts)
      -- Add Go-specific keymaps
      local maps = {
        n = {
          ["<leader>lG"] = { "<cmd>GoGen<cr>", desc = "Generate Go code" },
          ["<leader>lT"] = { "<cmd>GoTest<cr>", desc = "Run Go tests" },
          ["<leader>lR"] = { "<cmd>GoRun<cr>", desc = "Run Go file" },
          ["<leader>lB"] = { "<cmd>GoBuild<cr>", desc = "Build Go project" },
        },
      }
      
      if opts.keys then
        opts.keys = vim.tbl_deep_extend("force", opts.keys, maps)
      else
        opts.keys = maps
      end
    end,
  },

  -- Import organization and formatting on save (from official docs)
  {
    "LazyVim/LazyVim",
    opts = function(_, opts)
      -- Add Go-specific autocmds for import organization and formatting
      vim.api.nvim_create_autocmd("BufWritePre", {
        pattern = "*.go",
        callback = function()
          local params = vim.lsp.util.make_range_params()
          params.context = { only = { "source.organizeImports" } }
          
          -- Request organize imports action
          local result = vim.lsp.buf_request_sync(0, "textDocument/codeAction", params, 3000)
          for cid, res in pairs(result or {}) do
            for _, r in pairs(res.result or {}) do
              if r.edit then
                local enc = (vim.lsp.get_client_by_id(cid) or {}).offset_encoding or "utf-16"
                vim.lsp.util.apply_workspace_edit(r.edit, enc)
              end
            end
          end
          
          -- Format the file after organizing imports
          vim.lsp.buf.format({ async = false })
        end,
      })
    end,
  },

  -- Additional Go tools integration (if available)
  {
    "mfussenegger/nvim-dap",
    optional = true,
    dependencies = {
      {
        "leoluz/nvim-dap-go",
        config = function()
          require("dap-go").setup({
            -- Additional dap-go configuration
            delve = {
              path = "dlv", -- Assumes delve is in PATH
              initialize_timeout_sec = 20,
              port = "${port}",
              args = {},
              build_flags = "",
              dlvToolPath = vim.fn.exepath("dlv"),
            },
          })
        end,
      },
    },
  },

  -- Go testing integration
  {
    "nvim-neotest/neotest",
    optional = true,
    dependencies = {
      {
        "nvim-neotest/neotest-go",
        config = function()
          require("neotest-go").setup({
            -- Test configuration
            go_test_args = {
              "-v",
              "-race",
              "-count=1",
              "-timeout=30s",
            },
            dap_go_enabled = true,
          })
        end,
      },
    },
  },
}
