-- Go development helper commands
-- These commands provide quick access to common Go development tasks

local M = {}

-- Check if gopls is available
function M.has_gopls()
  return vim.fn.executable("gopls") == 1
end

-- Check if Go is available
function M.has_go()
  return vim.fn.executable("go") == 1
end

-- Go to definition (uses LSP if available, falls back to gofmt)
function M.go_to_definition()
  if M.has_gopls() then
    vim.lsp.buf.definition()
  else
    -- Fallback: use go doc or simple search
    local word = vim.fn.expand("<cword>")
    vim.cmd("split term://go doc " .. word)
  end
end

-- Run Go tests
function M.go_test()
  if M.has_go() then
    local cmd = "go test ./..."
    if vim.fn.expand("%:e") == "go" then
      -- Test current package only
      cmd = "go test ."
    end
    vim.cmd("split term://" .. cmd)
  else
    vim.notify("Go is not available", vim.log.levels.ERROR)
  end
end

-- Build Go project
function M.go_build()
  if M.has_go() then
    local cmd = "go build"
    if vim.fn.expand("%:e") == "go" then
      -- Build current file
      local file = vim.fn.expand("%:t:r")
      cmd = "go build -o " .. file
    end
    vim.cmd("split term://" .. cmd)
  else
    vim.notify("Go is not available", vim.log.levels.ERROR)
  end
end

-- Run Go file
function M.go_run()
  if M.has_go() then
    if vim.fn.expand("%:e") == "go" then
      local file = vim.fn.expand("%")
      vim.cmd("split term://go run " .. file)
    else
      vim.notify("Not a Go file", vim.log.levels.WARN)
    end
  else
    vim.notify("Go is not available", vim.log.levels.ERROR)
  end
end

-- Generate Go code (go generate)
function M.go_generate()
  if M.has_go() then
    vim.cmd("split term://go generate ./...")
  else
    vim.notify("Go is not available", vim.log.levels.ERROR)
  end
end

-- Format Go code
function M.go_format()
  if M.has_go() then
    vim.cmd("split term://go fmt ./...")
  else
    vim.notify("Go is not available", vim.log.levels.ERROR)
  end
end

-- Go mod tidy
function M.go_mod_tidy()
  if M.has_go() then
    vim.cmd("split term://go mod tidy")
  else
    vim.notify("Go is not available", vim.log.levels.ERROR)
  end
end

-- Setup Go commands
function M.setup()
  -- Create user commands
  vim.api.nvim_create_user_command("GoTest", M.go_test, { desc = "Run Go tests" })
  vim.api.nvim_create_user_command("GoBuild", M.go_build, { desc = "Build Go project" })
  vim.api.nvim_create_user_command("GoRun", M.go_run, { desc = "Run Go file" })
  vim.api.nvim_create_user_command("GoGen", M.go_generate, { desc = "Generate Go code" })
  vim.api.nvim_create_user_command("GoFmt", M.go_format, { desc = "Format Go code" })
  vim.api.nvim_create_user_command("GoModTidy", M.go_mod_tidy, { desc = "Tidy Go modules" })

  -- Set up Go file type specific settings (from official docs)
  vim.api.nvim_create_autocmd("FileType", {
    pattern = "go",
    callback = function()
      -- Set up omnifunc for completion (from official docs)
      -- In Neovim v0.8.1+ this is auto-set, but we set it manually for compatibility
      vim.api.nvim_buf_set_option(0, "omnifunc", "v:lua.vim.lsp.omnifunc")

      -- Set up local keymaps for Go files
      local opts = { buffer = true, silent = true }

      -- Navigation
      vim.keymap.set("n", "gd", M.go_to_definition, opts)
      vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)

      -- Quick actions
      vim.keymap.set("n", "<leader>gt", M.go_test, opts)
      vim.keymap.set("n", "<leader>gr", M.go_run, opts)
      vim.keymap.set("n", "<leader>gb", M.go_build, opts)
      vim.keymap.set("n", "<leader>gg", M.go_generate, opts)
      vim.keymap.set("n", "<leader>gf", M.go_format, opts)

      -- Module management
      vim.keymap.set("n", "<leader>gm", M.go_mod_tidy, opts)

      -- LSP-specific keymaps (only if gopls is available)
      if M.has_gopls() then
        vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
        vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
        vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)
        vim.keymap.set("n", "<C-k>", vim.lsp.buf.signature_help, opts)
        vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
        vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
        vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, opts)
        vim.keymap.set("n", "]d", vim.diagnostic.goto_next, opts)
        vim.keymap.set("n", "<leader>e", vim.diagnostic.open_float, opts)
      end

      -- Show Go status in status line if available
      if M.has_gopls() then
        vim.opt.statusline = vim.opt.statusline .. " %{GoStatus()}"
      end
    end,
  })

  -- Create a status function for Go
  function _G.GoStatus()
    if M.has_gopls() then
      return "🐹 gopls"
    elseif M.has_go() then
      return "🐹 go"
    else
      return ""
    end
  end
end

return M
