# Air-Gap Development Kit

A complete, offline-ready terminal development environment for Linux, designed for air-gapped systems. Choose the full package with WezTerm and fonts, or the CLI-only package for headless servers and SSH workflows. Both include tmux, Neovim, and modern CLI tools with zero internet dependency on the target machine.

[![GitHub Actions](https://img.shields.io/github/actions/workflow/status/jeeftor/airgap-dev-kit/update-binaries.yml)](https://github.com/jeeftor/airgap-dev-kit/actions)
[![Latest Release](https://img.shields.io/github/v/release/jeeftor/airgap-dev-kit)](https://github.com/jeeftor/airgap-dev-kit/releases/latest)

## ⚡ Quick Start

### Choose a Package

| Package | Use When | Includes |
| --- | --- | --- |
| `airgap-dev-kit-linux-x86_64.tar.gz` | You want the full desktop-friendly kit | WezTerm, fonts, CLI tools, Neovim, config |
| `airgap-dev-kit-cli.tar.gz` | You want headless Linux/SSH installs with no GUI prompts | CLI tools, tmux, Neovim, config; no WezTerm or fonts |

`airgap-dev-kit.tar.gz` is the default full Linux package alias. For servers, CI workers, and air-gapped boxes accessed over SSH, use `airgap-dev-kit-cli.tar.gz`.

### Full Linux Package (One-Liner)

**Using curl:**
```bash
curl -L https://github.com/jeeftor/airgap-dev-kit/releases/latest/download/airgap-dev-kit-linux-x86_64.tar.gz | tar -xz && cd airgap-dev-kit && ./install.sh
```

**Using wget:**
```bash
wget -qO- https://github.com/jeeftor/airgap-dev-kit/releases/latest/download/airgap-dev-kit-linux-x86_64.tar.gz | tar -xz && cd airgap-dev-kit && ./install.sh
```

### CLI-Only Linux Package (One-Liner)

```bash
curl -L https://github.com/jeeftor/airgap-dev-kit/releases/latest/download/airgap-dev-kit-cli.tar.gz | tar -xz && cd airgap-dev-kit && ./install.sh
```

The CLI-only package automatically runs in CLI-only mode. It skips WezTerm, skips font installation, disables GUI prompts, and asks before patching detected shell RC files for Starship, zoxide, fzf, and PATH. Set `AIRGAP_DEV_KIT_CONFIGURE_SHELLS=0` to skip shell RC edits, or `AIRGAP_DEV_KIT_CONFIGURE_SHELLS=1` to force shell setup in non-interactive installs.

### Traditional Install (with verification)

**Full Linux x86_64:**
```bash
# Download latest release
wget https://github.com/jeeftor/airgap-dev-kit/releases/latest/download/airgap-dev-kit-linux-x86_64.tar.gz
wget https://github.com/jeeftor/airgap-dev-kit/releases/latest/download/checksums.txt

# Verify the selected package
grep ' airgap-dev-kit-linux-x86_64.tar.gz$' checksums.txt | sha256sum -c -

# Extract and install
tar -xzf airgap-dev-kit-linux-x86_64.tar.gz
cd airgap-dev-kit
./install.sh
```

**CLI-only Linux x86_64:**
```bash
wget https://github.com/jeeftor/airgap-dev-kit/releases/latest/download/airgap-dev-kit-cli.tar.gz
wget https://github.com/jeeftor/airgap-dev-kit/releases/latest/download/checksums.txt

grep ' airgap-dev-kit-cli.tar.gz$' checksums.txt | sha256sum -c -

tar -xzf airgap-dev-kit-cli.tar.gz
cd airgap-dev-kit
./install.sh
```

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
# 1. Transfer airgap-dev-kit.tar.gz or airgap-dev-kit-linux-x86_64.tar.gz

# 2. Extract
tar -xzf airgap-dev-kit.tar.gz
cd airgap-dev-kit

# 3. Install
./install.sh

# 4. Add to PATH (add to ~/.bashrc or ~/.zshrc)
export PATH="$HOME/bin:$PATH"

# 5. Launch your environment
wezterm start -- tmux new-session nvim
```

**CLI-only package:**
```bash
# 1. Transfer airgap-dev-kit-cli.tar.gz

# 2. Extract
tar -xzf airgap-dev-kit-cli.tar.gz
cd airgap-dev-kit

# 3. Install without GUI prompts
./install.sh

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
- **mkcert** - Local HTTPS certificate generator (requires NSS tools on Linux)
- **gopls** - Go language server for IDE features (autocomplete, diagnostics, goto definitions)
- **delta** - Stunning git diff viewer with syntax highlighting
- **svu** - Semantic version utility for release management
- **stow** - GNU Stow for dotfile symlink management (bundled)
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
- ✅ **One-Command Install** - `./install.sh` does everything
- ✅ **Installation Tracking** - Complete undo system with automatic backups
- ✅ **Flexible Installation** - System-wide or user-local, with or without root
- ✅ **Reproducible** - Checksums and version pinning

## 📦 GitHub Actions Automation

This repository automatically builds fresh releases every Sunday with:
- All latest stable binaries
- Neovim plugins pre-downloaded via lazy.nvim
- SHA256 checksums for verification
- Ready-to-deploy packages

**Trigger a build:**
- Automatically: Every Sunday at midnight UTC
- Manually: Go to Actions → "Update Air-Gap Kit" → "Run workflow"
- On Push: When pushing config changes to master/main

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

After installation, you can use the unified `airgap-dev-kit` command:

```bash
airgap-dev-kit version     # Show kit version and installation info
airgap-dev-kit update      # Download/update all binaries (requires internet)
airgap-dev-kit install     # Install missing tools from offline packages
airgap-dev-kit status      # Show installation status of all tools
airgap-dev-kit remove      # Completely uninstall the airgap-dev-kit
airgap-dev-kit help        # Show help and available commands
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

2. Update `install.sh` to copy the binary:
```bash
cp offline-packages/linux/your-tool ~/bin/
```

## 📋 Installation Details

### What `install.sh` Does

1. **Prompts for installation location** - System-wide (`/usr/local/bin`) or user-local (`~/.local/bin`); CLI-only packages default to user-local unless run as root
2. **Checks OS** - Exits early outside Linux
3. **Installs binaries** - Copies to chosen location with version checking
4. **Extracts Neovim** - Unpacks and installs text editor
5. **Installs plugins** - Extracts pre-downloaded Neovim plugins
6. **Configures dotfiles** - Uses GNU Stow (if available) or direct copy
7. **Installs fonts** - JetBrainsMono Nerd Font for icons in the full package only
8. **Configures shell** - Optionally adds PATH and tool initialization to shell RC files; CLI-only packages prompt before patching interactive shells

### Directory Structure After Install

**System-wide install:**
```
/usr/local/bin/        # Binaries (requires sudo)
├── tmux, nvim, fzf, fd, rg, bat, starship
├── wezterm           # Full package only
└── (optional: btop, lsd, zoxide, direnv, dust, delta, svu, gum)
```

**User-local install:**
```
~/.local/bin/          # Binaries (no sudo needed)
├── tmux, nvim, fzf, fd, rg, bat, starship
├── wezterm           # Full package only
└── (optional: btop, lsd, zoxide, direnv, dust, delta, svu, gum)
```

**Configuration files (both install types):**
```
~/
├── .config/
│   ├── nvim/          # Neovim config (symlinked via Stow or copied)
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
- `tar`, `gzip` - Archive tools
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
# Add to ~/.bashrc or ~/.zshrc
export PATH="$HOME/.local/bin:$PATH"
source ~/.bashrc  # or ~/.zshrc

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
- Make sure you're running `./install.sh` from the extracted `airgap-dev-kit` directory
- Check that install.sh is executable: `chmod +x install.sh`

## 🗑️ Uninstallation

The kit includes a smart uninstaller that uses the installation log:

```bash
./uninstall.sh
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
