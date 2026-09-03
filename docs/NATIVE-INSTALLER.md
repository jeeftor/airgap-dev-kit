# Native installer contract

`airgap` is the supported installer for v2 release archives. It runs without a
network connection and records every created path for safe removal.

## Installation scopes

The installer separates shared commands from per-user state.

- `--scope=user` is the default. Commands are installed in `~/.local/bin`.
- `--scope=system` installs commands in `/usr/local/bin` and shared runtime
  assets in `/usr/local/share/airgap-dev-kit`. It uses `sudo` only for those
  paths.
- Neovim configuration, fonts, FZF integration, and shell startup changes are
  always owned by the invoking user, in either scope.

The interactive installer asks for the scope first and shows it again on the
review screen. Noninteractive system installs use:

```sh
./airgap install --yes --scope=system
```

Use `./airgap --demo` (or `./airgap install --demo`) for an interactive dry
run: it exercises the full setup without writing files or requesting sudo.
`--dry-run` prints the default or flag-based
plan without starting the TUI, which is better suited to automation.

The interactive flow separates location, package profile, and individual
components. Every compatible component starts selected; use Space to toggle an
item or `a` to select or clear the complete list.

## Safety rules

- Existing Neovim state is preserved by default; `replace` backs it up and
  `overwrite` explicitly removes it.
- Uninstall uses the recorded paths. For a system record, it refuses to remove
  anything outside `/usr/local/bin` and `/usr/local/share/airgap-dev-kit`.
- Config files are copied rather than symlinked, so an extracted removable kit
  can be disconnected or removed after installation.

## Legacy migration

The legacy shell installers remain temporarily while their historical install
log migration and release/test cleanup are completed. New release archives use
the native installer only; do not add new behavior to `install.sh`.
