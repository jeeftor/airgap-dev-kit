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

return config
