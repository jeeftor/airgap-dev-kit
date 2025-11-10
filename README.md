# Air-Gap Development Kit

A complete, offline-ready terminal development environment for macOS and Linux, designed for air-gapped systems. Features WezTerm, tmux, Neovim, and modern CLI tools—all bundled with zero internet dependency.

[![GitHub Actions](https://img.shields.io/github/actions/workflow/status/jeeftor/airgap-dev-kit/update-binaries.yml)](https://github.com/jeeftor/airgap-dev-kit/actions)
[![Latest Release](https://img.shields.io/github/v/release/jeeftor/airgap-dev-kit)](https://github.com/jeeftor/airgap-dev-kit/releases/latest)

## ⚡ Quick Start

### For Internet-Connected Machines

**Option 1: Download Latest Release (Recommended)**

```bash
# Download pre-built release from GitHub
wget https://github.com/jeeftor/airgap-dev-kit/releases/latest/download/airgap-dev-kit.tar.gz
wget https://github.com/jeeftor/airgap-dev-kit/releases/latest/download/checksums.txt

# Verify integrity
sha256sum -c checksums.txt

# Extract and install
tar -xzf airgap-dev-kit.tar.gz
cd airgap-dev-kit
./install.sh
```

**Option 2: Build From Source**

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
```

### For Air-Gapped Machines

```bash
# 1. Transfer airgap-dev-kit.tar.gz via USB/CD to air-gapped machine

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

### Optional Tools
- **btop** - Beautiful resource monitor (replaces htop/top)
- **lsd** - Modern ls with icons and colors
- **eza** - Another modern ls with git integration
- **zoxide** - Smarter cd that learns your habits
- **delta** - Stunning git diff viewer with syntax highlighting

### Extras
- **JetBrainsMono Nerd Font** - Patched font with programming ligatures and icons
- **Pre-configured Neovim** - With lazy.nvim, LSP, Treesitter, Telescope, and more
- **Shell completions** - For bash/zsh/fish
- **Man pages** - Offline documentation

## 🚀 Features

- ✅ **Zero Internet Dependency** - All binaries are static or self-contained
- ✅ **Automated Updates** - GitHub Actions builds fresh releases weekly
- ✅ **Cross-Platform** - Works on macOS (ARM64) and Linux (x86_64)
- ✅ **Air-Gap Ready** - Neovim plugins pre-bundled for offline use
- ✅ **One-Command Install** - `./install.sh` does everything
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

## 🛠️ Makefile Commands

```bash
make help              # Show all commands and status
make update            # Download all missing binaries
make verify            # Verify binaries are valid
make package           # Create deployment tarball
make install           # Install on current machine
make sync-nvim-config  # Sync ~/.config/nvim to repo
make clean             # Remove binaries (keep placeholders)
```

## 🎨 Customization

### Sync Your Neovim Config

```bash
# Copy your local Neovim config to the repo
make sync-nvim-config

# Commit and push (triggers new build with your config)
git add config/.config/nvim
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

1. **Detects OS** - Determines macOS vs Linux
2. **Copies binaries** - Installs to `~/bin/` (Linux) or system paths (macOS)
3. **Extracts Neovim** - Unpacks and installs text editor
4. **Installs plugins** - Extracts pre-downloaded Neovim plugins
5. **Symlinks configs** - Uses GNU Stow to link dotfiles
6. **Installs fonts** - JetBrainsMono Nerd Font for icons

### Directory Structure After Install

```
~/
├── bin/
│   ├── wezterm, tmux, nvim, fzf, fd, rg, bat, starship
│   └── (optional: btop, lsd, eza, zoxide, delta)
├── .config/
│   ├── nvim/          # Neovim config (via Stow)
│   ├── wezterm/       # Terminal config
│   └── starship.toml  # Prompt config
├── .tmux.conf         # Tmux config (via Stow)
└── .local/share/
    ├── fonts/         # JetBrainsMono Nerd Font
    └── nvim/lazy/     # Pre-installed Neovim plugins
```

## 🔧 Requirements

### Internet Machine (for building)
- `curl` - Download binaries
- `tar`, `gzip` - Archive tools
- `make` - Build automation

### Air-Gapped Machine (for installing)
- **GNU Stow** - Config symlink management
  - Debian/Ubuntu: `apt-get install stow`
  - RHEL/Fedora: `dnf install stow`
  - Arch: `pacman -S stow`
  - macOS: `brew install stow` (or include in kit)

## 📖 Documentation

- [CLAUDE.md](CLAUDE.md) - Comprehensive developer guide
- [Releases](https://github.com/jeeftor/airgap-dev-kit/releases) - Download pre-built packages
- [Actions](https://github.com/jeeftor/airgap-dev-kit/actions) - View build status

## 🐛 Troubleshooting

**Binaries not found after install:**
```bash
# Add to ~/.bashrc or ~/.zshrc
export PATH="$HOME/bin:$PATH"
source ~/.bashrc  # or ~/.zshrc
```

**Permission denied errors:**
```bash
chmod +x ~/bin/*
```

**macOS security warnings:**
```bash
# Remove quarantine attribute
xattr -cr /Applications/WezTerm.app
```

**Stow conflicts:**
```bash
# Remove old symlinks
stow -D config -t ~
# Backup conflicting files, then re-run
stow config -t ~
```

**Neovim plugins missing:**
- Ensure `offline-packages/lazy-plugins.tar.gz` exists
- GitHub Actions should bundle this automatically
- Or manually run: `nvim --headless "+Lazy! sync" +qa` on internet machine

## 🔐 Security

- Verify checksums: `sha256sum -c checksums.txt`
- All binaries from official GitHub releases
- Use write-protected media for transfer to air-gap
- Scan with antivirus before deployment

## 📊 Package Size

- **Minimal** (core tools only): ~150MB
- **Full** (all optional tools): ~250MB
- **With fonts**: ~350MB
- **Complete with plugins**: ~400MB

Use 1GB+ USB drive for comfortable transfer.

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch
3. Test on both macOS and Linux if possible
4. Submit pull request

## 📝 License

See individual tool licenses in their respective repositories. This kit is a distribution/packaging project.

## ⭐ Star History

If this project helps you, please star it on GitHub!

---

**Built for developers who work in secure, offline, or air-gapped environments** 🛡️
