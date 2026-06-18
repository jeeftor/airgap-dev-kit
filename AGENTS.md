# Repository Guidelines

## Project Structure & Module Organization

This repository packages an offline-ready terminal development kit for Linux. Treat Linux as the supported target unless a task explicitly asks for macOS. The `Makefile` is the main automation entry point for downloading binaries, verifying them, and creating deployable tarballs. Installer and lifecycle scripts live at the root (`install.sh`, `uninstall.sh`, `check-neovim.sh`, `install-mason-lsp.sh`) and in `scripts/`. Dotfiles and editor assets live under `config/`, including LazyVim at `config/nvim/.config/nvim/` and the plugin manifest at `config/plugin-manifest.lua`. Project documentation lives in `docs/`; Docker and Neovim/Mason test assets live in `test/`.

## Build, Test, and Development Commands

- `make` or `make help`: print available targets and current package status.
- `make update`: download missing Linux, font, and CLI binaries for offline packaging.
- `make verify`: confirm required binaries, fonts, and executable scripts are present and valid.
- `make package`: build `airgap-dev-kit.tar.gz` after verification.
- `make install`: run `./install.sh` on the current machine.
- `make check-updates`: query upstream releases via `scripts/check-updates.sh`.
- `./scripts/test-airgap-cli`: run basic CLI behavior and syntax checks for `scripts/airgap-dev-kit`.
- `./test-mason-docker.sh` or `bash test/test-with-manifest.sh` inside the Docker image: validate Neovim, LazyVim, and Mason packaging flows.

## Coding Style & Naming Conventions

Most project logic is POSIX shell or Make. Keep shell scripts readable, quote variables, prefer explicit error messages, and preserve existing root-script naming (`verb-noun.sh`) and helper naming under `scripts/`. Use tabs for Makefile recipes and keep the default `help` target first. Lua config should follow the existing LazyVim style and keep air-gap behavior intact, especially `install.missing = false`.

## Testing Guidelines

For packaging changes, run `make verify` before producing tarballs. For installer or CLI changes, run `./scripts/test-airgap-cli` and a Linux install smoke test when practical. For Neovim plugin or Mason changes, use the Docker workflow described in `test/README.md`; keep `config/plugin-manifest.lua` as the source of truth when using manifest-based plugin lists.

## Commit & Pull Request Guidelines

History mostly uses short imperative subjects, often Conventional Commit prefixes such as `feat:` and `fix:`. Keep commits focused, for example `fix: update Mason package names`. Pull requests should describe the packaging or install behavior changed, list verification commands run, and call out any generated artifacts, platform assumptions, or offline-package changes.

## Security & Configuration Tips

Do not commit generated tarballs, downloaded binaries, or local machine state unless the release workflow explicitly requires them. Keep internal registry, proxy, and certificate details out of public files. When changing download URLs or bundled versions, update the Makefile variables and rerun verification.

## Agent-Specific Instructions

Prioritize Linux behavior, Linux package contents, and Linux install/uninstall paths. Do not investigate or fix macOS-specific behavior unless the user explicitly asks for it.
