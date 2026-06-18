-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Enable clipboard integration with system clipboard
vim.opt.clipboard = "unnamedplus"

-- Enable mouse support (for clicking, selecting, scrolling)
vim.opt.mouse = "a"

-- Use system clipboard for all operations (including mouse selection in visual mode)
vim.opt.clipboard:append("unnamed")
