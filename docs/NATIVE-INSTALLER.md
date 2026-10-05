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

Use `vim-empty file.txt` to run `nvim` from your PATH with `-u NONE -i NONE`:
no user configuration, plugins, or ShaDa history. It also installs when you
preserve your existing Neovim profile and is tracked for uninstall. Before
upgrading, you can use `nvim -u NONE -i NONE file.txt` directly.

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
- Installed-command checks use the installation record. CLI-only installs and
  deselected tools do not fail because those commands are absent; recorded
  commands that disappear or lose executable permissions still fail.

## Legacy migration

The legacy shell installers remain temporarily while their historical install
log migration and release/test cleanup are completed. New release archives use
the native installer only; do not add new behavior to `install.sh`.

### Try WezTerm presets

Use `airgap wez list` to list the presets, then open a separate window:

```sh
airgap wez start current  # Your existing configuration
airgap wez start kit      # Bundled configuration, including middle-click paste
airgap wez start plain    # WezTerm defaults, without configuration
airgap wez start x11      # Bundled configuration with Wayland disabled
airgap wez start x11 --dry-run
```

These commands select a preset for the new window without changing your saved
configuration or existing windows. Installation stores a managed preset with the
WezTerm application, so `kit` and `x11` continue to work after you remove the USB.
Before installation, they use the configuration in the extracted kit. Existing
personal WezTerm configuration is preserved. Run them on your Linux desktop, rather than inside a remote
SSH session. The X11 preset requires an X11/XWayland display; compare it with
`kit` when testing window-edge resizing. CI verifies X11 launch and mouse paste;
it does not prove behavior on your GNOME/KDE Wayland desktop.

### Editor health and offline prerequisites

Installing the kit's Neovim and LazyVim profile automatically includes `fd`,
`fzf`, `rg`, and `lazygit`, even if you deselected them in the component picker.
The installer shows these required tools before confirmation and rejects an
incomplete payload before writing files. Both full and CLI-only installations
include them. The Neovim launcher adds the installed binary directory to its
own PATH, so menu launches work even when you decline shell integration.
Preserving an existing Neovim profile does not force these tool selections.

New editor payloads include the manifest's compiled Tree-sitter parsers, matching
queries, and a Tree-sitter CLI built from checksum-verified upstream source. The
connected Linux builder compiles them; editor startup does not install or update
parsers. LuaRocks is
disabled because the bundled plugin set does not require it. Mason does not
request downloads for unbundled tools; already installed language servers remain
available. Existing Neovim
profiles are preserved by default: choose `--nvim-mode=replace` to back up your
profile and install the kit configuration and payloads.

The CLI is statically linked with musl so it does not require the builder's glibc
version on Red Hat or Debian targets. The builder checks its ELF dependencies
and generates a sample parser before packaging. Native Linux builders need a
current Rust toolchain, the `x86_64-unknown-linux-musl` Rust target, `musl-gcc`,
and `readelf`; the Docker and GitHub builders prepare these dependencies in
their disposable environments. Cargo uses upstream's lockfile with `--locked`.
The connected builder uses a separately checksum-verified upstream GNU CLI to
compile and validate the shared parser libraries. That executable stays in the
temporary build directory; the kit contains only the portable generation CLI
and the compiled parsers.
This CLI supports parser generation; standalone `tree-sitter parse` loading
shared parser libraries is unavailable with static musl. Neovim loads and uses
the bundled shared parsers directly, which CI verifies separately.

Git remains a host prerequisite for Git integrations, including LazyGit and
LazyVim. Install the `git` package from your distribution's offline repository
(`dnf install git` on Red Hat, `apt install git` on Debian/Ubuntu). `airgap doctor`
warns when it cannot find Git. A C compiler, curl, and tar are needed to build
additional parsers, not to use the bundled compiled parsers. Upstream health
checks may still report these build prerequisites on minimal targets.

A local desktop clipboard provider requires `wl-clipboard` on Wayland or
`xclip`/`xsel` on X11. Installing one on an SSH server does not expose your local
desktop clipboard. WezTerm's terminal paste can insert text without a Neovim
clipboard provider. Clipboard history belongs to your desktop clipboard manager.

Capture your actual profile's diagnostics with:

```sh
nvim --headless '+checkhealth' '+write! /tmp/nvim-health.txt' '+qa!' \
  > /tmp/nvim-health-startup.txt 2>&1
```

Checkhealth reports problems; it does not repair them. Headless runs can report
UI initialization warnings. Missing optional remote-plugin providers, Mason
runtimes for languages you do not use, or dependencies of disabled image
features do not mean the offline editor is unusable. CI retains the complete
report and separately gates real offline parser loading, queries, highlighting,
the bundled CLI, and internal yank behavior.
The release workflow repeats the offline editor checks against the actual
release archive before signing and publishing, and retains its health evidence.
