# Changelog

## v2.8.0 - 2026-11-05

### Added

- Five matching offline themes for Kitty, Ghostty, and WezTerm: Monokai,
  Midnight, Forest, Ember, and Paper. Bundled presets default to Monokai.
- `airgap theme` lists palettes, saves a theme for kit-managed configurations,
  and opens temporary themed windows. Bash and Zsh shell integration provides
  the `theme` shortcut. Existing personal terminal configurations are preserved.
- Minimal Linux installation, offline multi-language project, and signed
  upgrade/rollback acceptance checks.

### Improved

- `airgap uninstall` previews recorded paths and prompts before removal in an
  interactive terminal. Enter cancels; `--yes` remains available for automation,
  and `--dry-run` remains a preview. System installations request sudo only
  after confirmation.
- Offline updates preserve your shell-integration choice and its uninstall
  tracking.

### Installation notes

- Extract the Linux x86-64 archive onto a local Linux filesystem, run
  `./airgap doctor --verify`, then `./airgap install`.
- Open a new shell for the `theme` alias. Try `theme start kitty paper`, or save
  a choice with `theme set monokai`. Open a new terminal window after saving.
- Terminal configurations preserved from earlier installations keep their
  colors. Saving a theme changes only recorded kit-managed configurations;
  original configurations are backed up before adding the first theme include.
- Physical desktops and native Wayland theme rendering still require target
  acceptance. Application themes, including Neovim's true-color scheme, remain
  controlled by those applications.
