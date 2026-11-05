# Portable Linux terminals

The full x86-64 Linux kit includes WezTerm, Kitty, and experimental Ghostty.
You can select them independently in the installer. No RPM or DEB installation
is needed. These GUI applications still require a working Linux desktop,
display server, and compatible graphics drivers. CLI-only kits exclude them.

| Terminal | Portable distribution | Mouse clipboard status |
| --- | --- | --- |
| WezTerm | Upstream AppImage | Kit preset handles middle-click even with application mouse capture |
| Kitty | Upstream binary bundle, including libraries and resources | Linux X11 tests pass native selection, tmux pane selection, and OpenCode 2 selection/middle-click |
| Ghostty (experimental) | Community AppImage from pkgforge-dev/ghostty-appimage, listed by Ghostty's installation documentation | Try on your target; application mouse capture can bypass terminal middle-click paste |

Run `wezterm`, `kitty`, or `ghostty` from your desktop terminal. Selected terminals
also get applications-menu entries when you enable menu integration. Removing
the kit removes its installed terminal payloads and launchers.

## Fonts and clipboard

All three presets select JetBrainsMono Nerd Font, installed by the full kit.
Select text and release to copy; middle-click is the intended paste workflow.
Ctrl+Shift+C/V remain available as additional shortcuts. The presets use
CLIPBOARD for native selection and middle-click so application OSC 52 copies
and terminal selections share the same destination. PRIMARY remains a separate
Linux selection and can contain different text.

Kitty and Ghostty advertise `xterm-256color`, which the bundled tmux AppImage
recognizes without installing additional terminfo entries. The tmux preset
keeps application mouse reporting and pane-aware selection.
OpenCode 2 can copy through OSC 52 without xclip or wl-clipboard installed.
Keyboard paste working alone does not establish that mouse paste works.

Ghostty's `middle-click-action = clipboard-paste` applies when Ghostty handles
the click itself. When an application enables mouse reporting, Ghostty forwards
the event to that application. In ordinary tmux shells, tmux may paste its own
buffer; inside a mouse-enabled application, the application must handle paste.
This does not guarantee the current desktop clipboard will be inserted. Keep
WezTerm or Kitty available if this workflow fails in Ghostty. We do not disable
mouse reporting globally, because that would change pane and application mouse
interaction.

Existing terminal configuration files are preserved. To try the kit's Kitty or
Ghostty preset explicitly without changing your own configuration, use:

```sh
kitty --config /path/to/extracted-kit/config/kitty/.config/kitty/kitty.conf
ghostty --config-file=/path/to/extracted-kit/config/ghostty/.config/ghostty/config
```

## Offline color themes

The bundled terminal presets use matching Monokai colors by default. Existing
personal configurations keep their colors. Five palettes are built into the
`airgap` command, so switching or trying a theme needs no downloads:

| Theme | Appearance |
| --- | --- |
| `monokai` | Default charcoal with vivid pink, green, and yellow |
| `midnight` | Dark blue with cool accents |
| `forest` | Dark green with muted natural colors |
| `ember` | Warm charcoal with amber accents |
| `paper` | Light cream with dark text |

When you enable shell integration, the installer adds `theme` as an alias for
`airgap theme` in Bash and Zsh. Open a new shell after installing, then use:

```sh
theme                              # List themes and examples
theme start kitty paper             # Try Paper in a new Kitty window
theme start ghostty forest          # Try Forest in a separate Ghostty instance
theme start wezterm ember           # Try Ember in a new WezTerm process
theme set monokai                   # Save Monokai for kit-managed configs
theme set midnight --terminal kitty # Save a different theme just for Kitty
theme set paper --dry-run           # Preview which configs would change
theme set default                   # Restore each preset's original colors
```

Without shell integration, use `airgap theme` in place of `theme`.
`start` uses your terminal's normal configuration plus a temporary color
override; it does not change the saved theme. Close that window when finished.
Keep the launching shell open while the preview runs.

`set` reads the installation record and updates only kit-managed terminal
configs. It saves the palette separately in
`~/.config/<terminal>/airgap-theme.conf` (`airgap-theme.lua` for WezTerm),
backing up the original config before adding its first theme include. Switching
themes keeps your fonts, clipboard settings, and keybindings. Open a new terminal
window after saving a theme. `default` removes the color override; fresh kit
presets return to Monokai, while older presets return to their original colors.

Personal configs that were preserved during installation are left unchanged.
For WezTerm, `airgap wez start kit` also applies the saved theme to the managed
preset, including system installations, without editing the shared preset.
Theme choices belong to the invoking user. Uninstall removes the recorded theme
files and preserves the original-config backups. Applications such as Neovim
that specify their own true-color themes keep those colors.

The launchers use native configuration overrides documented by
[Kitty](https://sw.kovidgoyal.net/kitty/invocation/),
[Ghostty](https://ghostty.org/docs/config/reference#config-file), and
[WezTerm](https://wezterm.org/cli/general.html).

## Target acceptance

On each Debian/Red Hat desktop, try a normal shell, a split tmux window, and
OpenCode 2 inside tmux. Select text, release, then middle-click into the input.
Also copy text in another desktop application and middle-click into the terminal.
A tmux-only buffer is not sufficient for that last check. Linux X11 automation
covers Kitty's mouse workflow; native Wayland and physical target graphics still
require testing. Ghostty is included to evaluate, not advertised as having
passed that mouse workflow.

## Updating portable artifacts

Kitty is pinned to 0.43.1 for older glibc compatibility: the 0.50.0 bundle
requires glibc 2.35 and fails on the tested AlmaLinux 9 host.

Kitty and Ghostty versions are pinned in `Makefile`. Their reviewed upstream
SHA-256 digests are pinned in `scripts/download-terminals.sh`; update both
when changing a terminal version. The weekly version updater currently does
not update these two pins. Downloading/repacking happens on the connected build
host. Kitty is repacked from xz to gzip so the target installer needs no xz tool.

Sources: [Kitty binaries](https://sw.kovidgoyal.net/kitty/binary/),
[Ghostty binaries](https://ghostty.org/docs/install/binary),
[community AppImage](https://github.com/pkgforge-dev/ghostty-appimage).
