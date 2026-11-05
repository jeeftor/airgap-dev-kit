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

-- Keep the command palette readable.
-- Ctrl+Shift+P is WezTerm's built-in command palette shortcut.
config.command_palette_bg_color = "#16161e"
config.command_palette_fg_color = "#c0caf5"
config.command_palette_rows = 14
config.ui_key_cap_rendering = "Emacs"

-- Paste the same CLIPBOARD that tmux and OpenCode write through OSC 52.
-- Handle the click even when tmux or an application captures mouse events.
config.mouse_bindings = {
  {
    event = { Down = { streak = 1, button = "Middle" } },
    mods = "NONE",
    mouse_reporting = false,
    action = wezterm.action.PasteFrom("Clipboard"),
  },
  {
    event = { Down = { streak = 1, button = "Middle" } },
    mods = "NONE",
    mouse_reporting = true,
    action = wezterm.action.PasteFrom("Clipboard"),
  },
}

-- Airgap default: Monokai. Change it with airgap theme set <name>.
config.colors = {
  background = "#272822", foreground = "#f8f8f2",
  cursor_bg = "#f8f8f2", cursor_fg = "#272822", cursor_border = "#f8f8f2",
  selection_bg = "#49483e", selection_fg = "#f8f8f2",
  ansi = {"#272822", "#f92672", "#a6e22e", "#f4bf75", "#66d9ef", "#ae81ff", "#a1efe4", "#f8f8f2"},
  brights = {"#75715e", "#f92672", "#a6e22e", "#f4bf75", "#66d9ef", "#ae81ff", "#a1efe4", "#f9f8f5"},
}

return config
