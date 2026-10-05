# Native installer contract

`airgap` is the supported installer for v2 release archives. It runs without a
network connection and records every created path for safe removal.

## Installation scopes

The installer separates shared commands from per-user state.

- `--scope=user` is the default. Commands are installed in `~/.local/bin`.
- `--scope=system` installs commands in `/usr/local/bin` and shared runtime
  assets in `/usr/local/share/airgap-dev-kit`. It uses `sudo` only for those
  paths.
- System authentication runs after the setup review and before installation
  progress, so your password prompt has normal terminal input.
- Neovim configuration, fonts, FZF integration, and shell startup changes are
  always owned by the invoking user, in either scope.
- When you select WezTerm, the interactive installer shows your Linux
  distribution and desktop session and offers an applications-menu entry,
  a menu entry plus an optional desktop shortcut, or no shortcuts. CLI-only
  installs skip this question. Distribution detection uses `os-release`;
  menu entries use the common Linux desktop-entry format.
- The applications-menu entry defaults to `WezTerm (Airgap)` in the selected
  scope. User menu entries honor `XDG_DATA_HOME`. Desktop shortcuts always
  belong to the invoking user and honor `XDG_DESKTOP_DIR` in your
  `user-dirs.dirs` configuration, including localized desktop directories.
  Uninstall removes the recorded menu entry and shortcut.
- Neovim uses the bundled Node runtime for Mason's JavaScript language tools.
  Mason launchers resolve their installed package rather than a build-host path.

The interactive installer asks for the scope first and shows it again on the
review screen. Noninteractive system installs use:

```sh
./airgap install --yes --scope=system
```

AppImage launchers use extraction mode so they also work when FUSE libraries or
device access are unavailable. They still require the application's normal Linux
graphics libraries.

For automation, choose GUI registration explicitly:

```sh
./airgap install --yes --desktop-integration=menu              # default
./airgap install --yes --desktop-integration=menu-and-desktop  # optional shortcut
./airgap install --yes --desktop-integration=none              # no shortcuts
```

A desktop shortcut requires desktop icons to be enabled. Your desktop may
also require you to choose **Allow Launching** or trust the launcher before
opening it. The installer creates an executable shortcut; it does not change
your desktop's trust policy or install desktop extensions.

Use `./airgap --demo` (or `./airgap install --demo`) for an interactive dry
run: it exercises the full setup without writing files or requesting sudo.
`--dry-run` prints the default or flag-based
plan without starting the TUI, which is better suited to automation.

The interactive flow separates location, package profile, and individual
components. Every compatible component starts selected; use Space to toggle an
item or `a` to select or clear the complete list.

## Clipboard and mouse paste

Use `vim-empty file.txt` to run `nvim` from your PATH with `--clean --noplugin`:
no user configuration, plugins, or ShaDa history. It also installs when you
preserve your existing Neovim profile and is tracked for uninstall. Before
upgrading, you can use `nvim --clean --noplugin file.txt` directly.

To capture health diagnostics for your configured LazyVim installation:

```sh
nvim --headless '+checkhealth' '+write! /tmp/nvim-health.txt' '+qa!' \
  > /tmp/nvim-health-startup.txt 2>&1
cat /tmp/nvim-health.txt
```

If startup fails before writing the report, inspect `/tmp/nvim-health-startup.txt`.
Use normal `nvim` for this report so your configured plugins are checked.

The bundled WezTerm handles middle-click itself, including inside LazyVim, and
pastes the desktop primary selection at the editor cursor. Existing WezTerm
configuration is preserved by installation; to use this behavior there, add the
`mouse_bindings` entry from the kit's WezTerm configuration. With default WezTerm
bindings, holding Shift while middle-clicking provides the same bypass.

Neovim's `"+` and `"*` clipboard registers require a desktop clipboard provider.
Install `wl-clipboard` for a Wayland session or `xclip` for X11 from your approved
distribution repositories or offline package media, then restart Neovim. These
desktop packages are not bundled. The kit enables automatic clipboard registers
only when Neovim detects a provider; editing without one uses internal registers.
`:checkhealth vim.provider` diagnoses providers and does not install or repair
them. Other health warnings need their own reported remediation.

## Safety rules

- Existing Neovim state is preserved by default; `replace` backs it up and
  `overwrite` explicitly removes it.
- Uninstall uses the recorded paths. For a system record, it refuses to remove
  shared paths outside `/usr/local/bin`, `/usr/local/share/airgap-dev-kit`, and
  the exact `/usr/local/share/applications/airgap-wezterm.desktop` file.
- Config files are copied rather than symlinked, so an extracted removable kit
  can be disconnected after installation. Keep the extracted kit available for
  `doctor --verify`: installed commands discover it through the installation
  record without requiring `AIRGAP_KIT_DIR`.

## Legacy migration

The legacy shell installers remain temporarily while their historical install
log migration and release/test cleanup are completed. New release archives use
the native installer only; do not add new behavior to `install.sh`.
