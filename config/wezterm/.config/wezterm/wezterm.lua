-- Air-Gap Dev Kit WezTerm configuration.
-- GUI behavior belongs here; tmux remains responsible for terminal panes.
local wezterm = require "wezterm"
local config = wezterm.config_builder()

config.font = wezterm.font_with_fallback({
  "JetBrainsMono Nerd Font",
  "JetBrains Mono",
})
config.font_size = 12.0

-- Keep native window controls and a resizable border available.
config.window_decorations = "TITLE | RESIZE"
config.window_padding = {
  left = 8,
  right = 8,
  top = 6,
  bottom = 6,
}

-- Tabs are a GUI-level concern. Do not add WezTerm pane bindings here: tmux
-- owns splits, pane navigation, and pane resizing inside each terminal tab.
config.enable_tab_bar = true
config.hide_tab_bar_if_only_one_tab = true

-- Keep the command palette readable without changing terminal or tmux colors.
-- Ctrl+Shift+P is WezTerm's built-in command palette shortcut.
config.command_palette_bg_color = "#16161e"
config.command_palette_fg_color = "#c0caf5"
config.command_palette_rows = 14
config.ui_key_cap_rendering = "Emacs"

return config
