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

The tmux preset keeps application mouse reporting and pane-aware selection.
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
