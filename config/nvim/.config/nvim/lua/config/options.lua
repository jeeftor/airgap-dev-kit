-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Minimal offline hosts may have no desktop clipboard tool. Keep ordinary
-- editing usable; explicit system clipboard registers still need a provider.
vim.opt.clipboard = vim.fn.has("clipboard") == 1 and "unnamedplus,unnamed" or ""

-- Enable mouse support (for clicking, selecting, scrolling)
vim.opt.mouse = "a"
