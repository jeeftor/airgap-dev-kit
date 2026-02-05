# CLAUDE.md

Air-gap dev kit for offline terminal environment (WezTerm, tmux, Neovim/LazyVim, CLI tools).

## Quick Start

```bash
# Build (online machine)
make update && make verify && make package

# Install (air-gapped machine)
tar -xzf airgap-dev-kit.tar.gz && cd airgap-dev-kit && ./install.sh
```

## Structure

- `install.sh` - Interactive installer (OS detection, version checking, shell config)
- `offline-packages/{linux,macos}/` - Static binaries
- `config/` - Dotfiles (Stow-managed)
- `Makefile` - Download/verify/package automation

## Development

**Add binary**: Update `Makefile` + `install.sh` BINARIES_TO_CHECK, then `make update && make verify`
**Update versions**: Edit `Makefile` variables, `make clean && make update && make package`
**Test**: `make install` or `docker run -it --rm -v $(pwd):/mnt ubuntu:22.04 bash`

## Key Files

- `Makefile` - Version variables, download URLs
- `install.sh` - Binary installation, shell configuration (lines 397-424 for BINARIES_TO_CHECK)
- `config/.config/nvim/` - LazyVim config (must have `install.missing=false` for air-gap)

## Notes

- Binaries: Static/musl builds for portability
- LazyVim plugins: Bundled by GitHub Actions or manually (`nvim --headless "+Lazy! sync" +qa`)
- Installer: System-wide (/usr/local/bin) or user-local (~/.local/bin), logs to ~/.airgap-dev-kit-install.log
- Uninstall: `./uninstall.sh` (removes all, creates backups)
