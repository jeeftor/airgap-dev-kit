package cli

import (
	"fmt"
	"strings"
)

type terminalTheme struct {
	Name, Description                 string
	Background, Foreground, Selection string
	Palette                           [16]string
}

// Keep one palette per theme so all three terminals display the same colors.
var terminalThemes = []terminalTheme{
	{
		Name: "monokai", Description: "Default: charcoal with vivid pink, green, and yellow",
		Background: "#272822", Foreground: "#f8f8f2", Selection: "#49483e",
		Palette: [16]string{
			"#272822", "#f92672", "#a6e22e", "#f4bf75", "#66d9ef", "#ae81ff", "#a1efe4", "#f8f8f2",
			"#75715e", "#f92672", "#a6e22e", "#f4bf75", "#66d9ef", "#ae81ff", "#a1efe4", "#f9f8f5",
		},
	},
	{
		Name: "midnight", Description: "Dark blue background with cool accents",
		Background: "#171d2b", Foreground: "#d8e2f0", Selection: "#344563",
		Palette: [16]string{
			"#222b3c", "#ed8796", "#a6da95", "#eed49f", "#8aadf4", "#c6a0f6", "#8bd5ca", "#c4cfe0",
			"#65748c", "#f5a0ad", "#b8e5aa", "#f5dfb3", "#a4bfff", "#d5b5ff", "#a4e4db", "#f0f4fc",
		},
	},
	{
		Name: "forest", Description: "Dark green background with muted natural colors",
		Background: "#18231f", Foreground: "#d9e2d5", Selection: "#3b5145",
		Palette: [16]string{
			"#23332b", "#d98686", "#a6c78c", "#d8c18a", "#8fafc4", "#b69ac4", "#88bcb0", "#c4d0be",
			"#697f70", "#eba2a2", "#bedaa6", "#eddaa3", "#a7c8dc", "#cfb4dd", "#a1d5c9", "#edf3e7",
		},
	},
	{
		Name: "ember", Description: "Warm charcoal background with amber accents",
		Background: "#29221e", Foreground: "#e8dbc5", Selection: "#594536",
		Palette: [16]string{
			"#382d26", "#dc8070", "#abb980", "#dfb56d", "#8caeb5", "#bd94aa", "#8cbba5", "#d4c5ac",
			"#8b7763", "#efa08c", "#c4d09c", "#f2d08c", "#a8cbd2", "#d6b0c6", "#a8d6bf", "#fff0d7",
		},
	},
	{
		Name: "paper", Description: "Light cream background with dark, readable colors",
		Background: "#faf6ed", Foreground: "#343b45", Selection: "#d8e2ec",
		Palette: [16]string{
			"#343b45", "#a52f3d", "#396b35", "#845b10", "#285d9b", "#75449a", "#176c70", "#c6c0b5",
			"#666d77", "#bd384b", "#477f3e", "#956719", "#3671b2", "#8b54af", "#227d82", "#fffdf7",
		},
	},
}

func findTerminalTheme(name string) (terminalTheme, error) {
	for _, theme := range terminalThemes {
		if theme.Name == name {
			return theme, nil
		}
	}
	return terminalTheme{}, fmt.Errorf("unknown terminal theme %q; run 'airgap theme list'", name)
}

func terminalThemeConfig(terminal string, theme terminalTheme) (string, error) {
	var config strings.Builder
	switch terminal {
	case "kitty":
		fmt.Fprintf(&config, "# Airgap theme: %s\nbackground %s\nforeground %s\ncursor %s\ncursor_text_color %s\nselection_background %s\nselection_foreground %s\n", theme.Name, theme.Background, theme.Foreground, theme.Foreground, theme.Background, theme.Selection, theme.Foreground)
		for index, color := range theme.Palette {
			fmt.Fprintf(&config, "color%d %s\n", index, color)
		}
	case "ghostty":
		fmt.Fprintf(&config, "# Airgap theme: %s\nbackground = %s\nforeground = %s\ncursor-color = %s\ncursor-text = %s\nselection-background = %s\nselection-foreground = %s\n", theme.Name, theme.Background, theme.Foreground, theme.Foreground, theme.Background, theme.Selection, theme.Foreground)
		for index, color := range theme.Palette {
			fmt.Fprintf(&config, "palette = %d=%s\n", index, color)
		}
	case "wezterm":
		fmt.Fprintf(&config, "-- Airgap theme: %s\nreturn {\n  background = %q, foreground = %q,\n  cursor_bg = %q, cursor_fg = %q, cursor_border = %q,\n  selection_bg = %q, selection_fg = %q,\n", theme.Name, theme.Background, theme.Foreground, theme.Foreground, theme.Background, theme.Foreground, theme.Selection, theme.Foreground)
		for group, colors := range [][]string{theme.Palette[:8], theme.Palette[8:]} {
			key := "ansi"
			if group == 1 {
				key = "brights"
			}
			fmt.Fprintf(&config, "  %s = {", key)
			for _, color := range colors {
				fmt.Fprintf(&config, "%q,", color)
			}
			config.WriteString("},\n")
		}
		config.WriteString("}\n")
	default:
		return "", fmt.Errorf("unknown terminal %q; use kitty, ghostty, or wezterm", terminal)
	}
	return config.String(), nil
}
