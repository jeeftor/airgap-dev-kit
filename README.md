# Air-Gap Development Kit

A complete, offline-ready terminal development environment for Linux, designed for air-gapped systems. Choose the full package with WezTerm and fonts, or the CLI-only package for headless servers and SSH workflows. Both include tmux, Neovim, and modern CLI tools with zero internet dependency on the target machine.

[![GitHub Actions](https://img.shields.io/github/actions/workflow/status/jeeftor/airgap-dev-kit/release.yml)](https://github.com/jeeftor/airgap-dev-kit/actions)
[![Latest Release](https://img.shields.io/github/v/release/jeeftor/airgap-dev-kit)](https://github.com/jeeftor/airgap-dev-kit/releases/latest)

## ⚡ Quick Start

### Choose a Package

| Package | Use When | Includes |
| --- | --- | --- |
| `airgap-dev-kit-linux-x86_64.tar.gz` | You want the full desktop-friendly kit | WezTerm, fonts, CLI tools, Neovim, config |
| `airgap-dev-kit-cli.tar.gz` | You want headless Linux/SSH installs with no GUI prompts | CLI tools, tmux, Neovim, config; no WezTerm or fonts |

`airgap-dev-kit.tar.gz` is the default full Linux package alias. For servers, CI workers, and air-gapped boxes accessed over SSH, use `airgap-dev-kit-cli.tar.gz`.

### Verified Install

Do not pipe a release archive directly into `tar` or the installer. Download the archive and its checksum first, verify them, then extract. The kit's `make download-release` target resolves one release, downloads both assets to temporary names, validates SHA-256, and only then writes them to the destination directory.

**Full Linux x86_64:**
```bash
# Download and verify one resolved GitHub release
make download-release RELEASE_DIR="$HOME/Downloads/airgap-dev-kit"
cd "$HOME/Downloads/airgap-dev-kit"

# Optional provenance verification on the connected machine
gh attestation verify airgap-dev-kit-linux-x86_64.tar.gz --repo jeeftor/airgap-dev-kit

# Extract and install
tar -xzf airgap-dev-kit-linux-x86_64.tar.gz
cd airgap-dev-kit
./airgap install
```

**CLI-only Linux x86_64:**
```bash
# Use the full package unless you intentionally need the headless build.
# Download the CLI release and checksums, verify its matching SHA-256 entry,
# then extract and run ./airgap install. The .airgap-cli-only marker enables this mode.
```

The CLI-only package skips WezTerm and fonts. `airgap install` creates `~/.config/airgap-dev-kit/shell.sh` and appends one idempotent, clearly marked `source` block to detected Bash/Zsh startup files; use `--configure-shell=false` to opt out.

### Build From Source

```bash
# Clone repository
git clone https://github.com/jeeftor/airgap-dev-kit.git
cd airgap-dev-kit

# Download all binaries
make update

# Verify downloads
make verify

# Install on current machine
make install

# Or create package for transfer
make package

# Or create a CLI-only package for headless Linux installs
make package-cli
```

### For Air-Gapped Machines

**Full package:**
```bash
# 1. On the connected machine, use the verified-install process above.
#    Transfer the verified archive AND checksums.txt on write-protected media.

# 2. On the air-gapped machine, re-check the archive after transfer.
grep ' airgap-dev-kit-linux-x86_64.tar.gz$' checksums.txt | sha256sum -c -

# 3. Extract
tar -xzf airgap-dev-kit-linux-x86_64.tar.gz
cd airgap-dev-kit

# 4. Install
./airgap install

# 4. Add to PATH (add to ~/.bashrc or ~/.zshrc)
export PATH="$HOME/bin:$PATH"

# 5. Launch your environment
wezterm start -- tmux new-session nvim
```

### WezTerm and tmux

The full package installs a WezTerm configuration at `~/.config/wezterm/wezterm.lua`.
It uses JetBrainsMono Nerd Font, retains native window resizing, and shows a tab bar
when you open more than one WezTerm tab. It intentionally does not redefine pane
shortcuts: tmux owns terminal splits, navigation, and resizing.

- WezTerm defaults: `Ctrl+Shift+C` / `Ctrl+Shift+V` copy and paste, `Ctrl+Shift+T` opens a tab, and `Ctrl+Shift+W` closes one.
- tmux: `Ctrl+b`, then `Ctrl+Arrow` resizes a pane; `Alt+Arrow` changes panes.

**CLI-only package:**
```bash
# 1. Transfer airgap-dev-kit-cli.tar.gz

# 2. Extract
tar -xzf airgap-dev-kit-cli.tar.gz
cd airgap-dev-kit

# 3. Install without GUI prompts
./airgap install

# 4. Add to PATH if using a user-local install
export PATH="$HOME/.local/bin:$PATH"

# 5. Launch your environment
tmux new-session nvim
```

## 🎯 What's Included

### Core Tools
- **WezTerm** - GPU-accelerated terminal emulator
- **tmux** - Terminal multiplexer with mouse support
- **Neovim** - Modern text editor with LSP and plugins

### CLI Essentials
- **fzf** - Fuzzy finder for files and commands
- **fd** - Fast, user-friendly alternative to `find`
- **ripgrep (rg)** - Lightning-fast text search
- **bat** - Cat with syntax highlighting and git integration
- **starship** - Beautiful, fast shell prompt
- **airgap-dev-kit** - Unified CLI wrapper for managing the kit

### Optional Tools
- **btop** - Beautiful resource monitor (replaces htop/top)
- **lsd** - Modern ls with icons and colors
- **zoxide** - Smarter cd that learns your habits
- **direnv** - Automatic per-directory environment loader
- **dust** - Fast, intuitive disk usage visualizer
- **gdu** - Interactive disk usage analyzer with TUI
- **usbtree** - Live USB device tree viewer
- **glow** - Render Markdown docs in the terminal
- **broot** - Interactive, fuzzy directory tree navigator
- **fastfetch** - Fast system information summary
- **mkcert** - Local HTTPS certificate generator (requires NSS tools on Linux)
- **gopls** - Go language server for IDE features (autocomplete, diagnostics, goto definitions)
- **delta** - Stunning git diff viewer with syntax highlighting
- **svu** - Semantic version utility for release management
- **stow** - GNU Stow for dotfile symlink management (used when already installed)
- **gum** - Charm Bracelet TUI toolkit for pretty prompts (bundled)

### Language Support
- **Go** - Complete LSP support with gopls (autocomplete, diagnostics, goto definitions)
- **Lua** - Built-in LSP support
- **Shell** - Basic syntax highlighting and completion

### Go Development Features
- **gopls integration** - Full IDE features for Go development
- **Quick commands** - `<leader>lT` (test), `<leader>lR` (run), `<leader>lB` (build)
- **Code generation** - Automatic Go code generation support
- **Testing integration** - Run tests directly from Neovim
- **Debugging support** - DAP integration (if delve is available)

### Extras
- **JetBrainsMono Nerd Font** - Patched font with programming ligatures and icons
- **Pre-configured Neovim** - With lazy.nvim, LSP, Treesitter, Telescope, and more
- **Shell completions** - For bash/zsh/fish
- **Man pages** - Offline documentation

The CLI-only package omits WezTerm and JetBrainsMono Nerd Font to keep installs non-GUI and non-interactive.

## 🚀 Features

- ✅ **Zero Internet Dependency** - All binaries are static or self-contained
- ✅ **Automated Updates** - GitHub Actions builds fresh releases weekly
- ✅ **Linux-Focused** - Supports Linux x86_64 install and package workflows
- ✅ **Air-Gap Ready** - Neovim plugins pre-bundled for offline use
- ✅ **One-Command Install** - `./airgap install` does everything
- ✅ **Installation Tracking** - Complete undo system with automatic backups
- ✅ **Flexible Installation** - System-wide or user-local, with or without root
- ✅ **Reproducible** - Checksums and version pinning

## 📦 GitHub Actions Automation

This repository publishes a release only from an explicit SemVer tag, with:
- Version-pinned Linux binaries
- Neovim plugins and Mason payloads built from the committed manifest
- SHA256 checksums for verification
- Ready-to-deploy packages

**Publish a release:**

```bash
git tag -a vX.Y.Z -m "Release vX.Y.Z"
git push origin vX.Y.Z
```

The `Release Air-Gap Kit` workflow is the only publisher. Pushes and pull
requests run validation only; they never create GitHub Releases.

**Security & Provenance:**
- ✅ **SLSA Attestations** - All releases include cryptographic provenance
- ✅ **GitHub Artifact Attestations** - Built-in supply chain security
- ✅ **Verified Builds** - Cryptographically signed build metadata

## 🛠️ Makefile Commands

```bash
make help              # Show all commands and status
make update            # Download all missing binaries
make verify            # Verify binaries are valid
make package           # Create full deployment tarball
make package-cli       # Create CLI-only tarball
make docker-test       # Smoke test full package in Docker
make test-cli-package  # Test CLI-only package layout and dry-run behavior
make install           # Install on current machine
make sync-nvim-config  # Sync ~/.config/nvim to repo
make clean             # Remove binaries (keep placeholders)
```

## 🚀 airgap-dev-kit CLI

After extraction, use the unified `airgap` command:

```bash
airgap version             # Show kit version and installation info
airgap update check        # Check signed kit releases (on a connected machine)
airgap install             # Install the extracted offline payload
airgap status              # Show kit status
airgap uninstall --yes     # Remove only paths tracked by airgap
airgap --help              # Show help and available commands
```

This provides a simple interface for managing your air-gap development environment without needing to remember individual make commands or script locations.

## 🎨 Customization

### Sync Your Neovim Config

```bash
# Copy your local Neovim config to the repo
make sync-nvim-config

# Commit and push (triggers new build with your config)
git add config/nvim/.config/nvim
git commit -m "Update Neovim config"
git push
```

### Add Custom Tools

1. Edit `Makefile` and add download target:
```makefile
@if [ ! -f offline-packages/linux/your-tool ]; then
    curl -fL "https://..." -o offline-packages/linux/your-tool
    chmod +x offline-packages/linux/your-tool
fi
```

2. Add the tool to the v2 install mapping in `internal/cli/install.go` when it needs a different installed name.

## 📋 Installation Details

### What `airgap install` Does

1. **Installs user-local binaries** - Copies the extracted payload to `~/.local/bin` without network access
2. **Makes Neovim self-contained** - The `nvim` launcher sets `VIMRUNTIME` to the bundled runtime before starting Neovim
3. **Protects existing Neovim state** - Preserves it by default, or backs up the complete profile before `--nvim-mode=replace`
4. **Activates offline LazyVim and Mason** - Extracts the matching bundled plugin and LSP payloads
5. **Configures Bash/Zsh safely** - Writes one managed shell source file and appends a removable, idempotent `source` block; use `--configure-shell=false` to opt out

For an unattended replacement of a previous Neovim setup, run `./airgap install --yes --nvim-mode=replace`. The prior state is retained under `~/.local/share/airgap-dev-kit/backups/`; use `--nvim-mode=preserve` to skip the kit's Neovim components explicitly.

### Directory Structure After Install

**System-wide install:**
```
/usr/local/bin/        # Binaries (requires sudo)
├── tmux, nvim, fzf, fd, rg, bat, starship
├── wezterm           # Full package only
└── (optional: btop, lsd, zoxide, direnv, dust, delta, svu, gum, glow, broot, fastfetch)
```

**User-local install:**
```
~/.local/bin/          # Binaries (no sudo needed)
├── tmux, nvim, fzf, fd, rg, bat, starship
├── wezterm           # Full package only
└── (optional: btop, lsd, zoxide, direnv, dust, delta, svu, gum, glow, broot, fastfetch)
```

**Configuration files (both install types):**
```
~/
├── .config/
│   ├── nvim/          # Neovim config (symlinked via Stow or copied)
│   ├── wezterm/       # WezTerm GUI configuration
│   └── starship.toml  # Prompt config
├── .tmux.conf         # Tmux config
└── .local/share/
    ├── fonts/         # JetBrainsMono Nerd Font
    └── nvim/lazy/     # Pre-installed Neovim plugins
```

CLI-only installs do not create `~/.local/share/fonts/` from this kit and do not install `wezterm`.

## 🔧 Requirements

### Internet Machine (for building)
- `curl` - Download binaries
- `tar`, `gzip`, `unzip` - Archive tools
- `make` - Build automation

### Air-Gapped Machine (for installing)
- **No external dependencies required!**
  - GNU Stow is bundled in the package for dotfile management
  - Falls back to direct copy if Stow fails
  - Everything needed is included

## 📖 Documentation

- [INSTALLATION-TRACKING.md](INSTALLATION-TRACKING.md) - Installation tracking & undo system
- [config/README.md](config/README.md) - GNU Stow configuration guide
- [CHANGES.md](CHANGES.md) - Recent changes and improvements
- [CLAUDE.md](CLAUDE.md) - Comprehensive developer guide
- [Releases](https://github.com/jeeftor/airgap-dev-kit/releases) - Download pre-built packages
- [Actions](https://github.com/jeeftor/airgap-dev-kit/actions) - View build status

## 🐛 Troubleshooting

**Binaries not found after user-local install:**
```bash
# Add to the RC file for your shell
export PATH="$HOME/.local/bin:$PATH"
source ~/.bashrc  # bash
source ~/.zshrc   # zsh only; do not run this from bash

# Or if you used ~/bin instead:
export PATH="$HOME/bin:$PATH"
```

**Permission denied errors:**
```bash
# For user-local install
chmod +x ~/.local/bin/*

# For system-wide install (if needed)
sudo chmod +x /usr/local/bin/*
```

**Can't install system-wide (no sudo access):**
- Choose option 2 (user-local install) when prompted
- Installer will automatically use `~/.local/bin`
- Remember to add to PATH as shown above

**Stow conflicts:**
```bash
# The installer now handles this automatically with backups
# But if you need to manually fix:

# Remove old symlinks
cd config && stow -D -t ~ */

# Backup conflicting files
mv ~/.config/nvim ~/.config/nvim.backup

# Re-stow
cd config && stow -t ~ */
```

**Config directory structure issues:**
```bash
# If you're getting Stow errors, restructure the config directory:
./restructure-config-for-stow.sh

# See config/README.md for details on proper Stow structure
```

**Neovim plugins missing:**
- Ensure `offline-packages/lazy-plugins.tar.gz` exists
- GitHub Actions should bundle this automatically
- Or manually run: `nvim --headless "+Lazy! sync" +qa` on internet machine

**Installation fails with "command not found":**
- Make sure you're running `./airgap install` from the extracted `airgap-dev-kit` directory
- Check that the root launcher is executable: `chmod +x airgap`

## 🗑️ Uninstallation

The kit includes a smart uninstaller that uses the installation log:

```bash
./airgap uninstall --yes
```

**Features:**
- ✅ Reads installation log (`~/.airgap-dev-kit-install.log`)
- ✅ Shows exactly what will be removed
- ✅ Preserves backups created during installation
- ✅ Properly unstows Stow packages
- ✅ Cleans shell configurations
- ✅ Falls back to manual search if no log exists

**What gets removed:**
- All installed binaries
- Configuration files (with confirmation)
- Neovim plugins and data
- Shell RC modifications
- Fonts (optional)

**What gets preserved:**
- Backup files (`.backup-*` files)
- Shell config backups (`.bashrc.airgap-backup`)
- Custom modifications you made

See [INSTALLATION-TRACKING.md](INSTALLATION-TRACKING.md) for details.

## 🔐 Security

- Verify the package you downloaded, for example: `grep ' airgap-dev-kit-cli.tar.gz$' checksums.txt | sha256sum -c -`
- All binaries from official GitHub releases
- Use write-protected media for transfer to air-gap
- Scan with antivirus before deployment

## 📊 Package Size

- **CLI-only release package**: smaller server-focused tarball without WezTerm or fonts
- **Full release package**: desktop-friendly tarball with WezTerm and fonts
- **Complete with plugins**: largest package because Neovim plugins and Mason payloads are bundled

Use 1GB+ USB drive for comfortable transfer.

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch
3. Test on Linux with the repo-native checks
4. Submit pull request

## 📝 License

See individual tool licenses in their respective repositories. This kit is a distribution/packaging project.

## ⭐ Star History

If this project helps you, please star it on GitHub!

---

**Built for developers who work in secure, offline, or air-gapped environments** 🛡️
