# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an **air-gap development kit** designed for offline installation of a complete terminal development environment on both macOS and Linux systems, including air-gapped machines. The kit bundles static binaries and configurations for:

**Core Tools:**
- WezTerm - GPU-accelerated terminal emulator
- tmux - Terminal multiplexer
- Neovim - Modern text editor

**Essential CLI Tools:**
- fzf - Fuzzy finder for files/commands
- fd - Fast alternative to `find`
- ripgrep (rg) - Fast text search
- bat - Cat with syntax highlighting
- starship - Cross-shell prompt

**Optional Utilities:**
- btop - Beautiful resource monitor (replaces htop/top)
- eza - Modern ls replacement with git integration
- zoxide - Smarter cd that learns your habits
- delta - Beautiful git diff viewer with syntax highlighting
- gum - Charm Bracelet TUI toolkit for beautiful interactive prompts

## Quick Start

**Automated Updates via GitHub Actions (Recommended):**
GitHub Actions automatically builds fresh releases weekly (Sundays) with all binaries and Neovim plugins bundled. Just download the latest release from the Releases page!

**Manual Build on Internet Machine:**
```bash
# 1. Download all binaries
make update

# 2. Verify everything downloaded correctly
make verify

# 3. Package for deployment
make package
# Creates: airgap-dev-kit.tar.gz

# Note: Neovim plugins are now automatically bundled by GitHub Actions
# If building manually and you have a Neovim config in config/.config/nvim/,
# plugins will be included in the package
```

**On Air-Gapped Machine:**
```bash
# Extract and install
tar -xzf airgap-dev-kit.tar.gz
cd airgap-dev-kit
./install.sh  # Interactive installer with version checking

# The installer will:
# 1. Detect your OS (Linux/macOS)
# 2. Prompt for installation location (/usr/local/bin or ~/bin)
# 3. Check for existing binaries and show version comparisons
# 4. Use gum for beautiful interactive prompts (if available)
# 5. Install all binaries and configs

# 2. Add to PATH if needed (installer will guide you)
export PATH="$HOME/bin:$PATH"  # Only if installed to ~/bin

# 3. Launch
wezterm start -- tmux new-session nvim  # If /usr/local/bin
# or
~/bin/wezterm start -- ~/bin/tmux new-session ~/bin/nvim  # If ~/bin
```

## What's Included

- **Terminal**: WezTerm (AppImage for Linux, .app for macOS)
- **Multiplexer**: tmux 3.4 static binary
- **Editor**: Neovim nightly (static builds)
- **Tools**: fzf, fd, ripgrep, bat, starship, lsd (all static/musl binaries)
- **Font**: JetBrainsMono Nerd Font (112MB, includes icons)
- **Configs**: Managed via GNU Stow (symlinks to ~/.config/)
- **Plugins**: Neovim plugins pre-downloaded with lazy.nvim
- **Docs**: Man pages, shell completions (bash/zsh/fish)

## Architecture

### Directory Structure

- `install.sh` - Single entry point installer that detects OS and deploys everything
- `offline-packages/` - Contains all binaries organized by platform
  - `linux/` - Static musl binaries for maximum portability (AppImage, static builds)
  - `macos/` - macOS ARM64 binaries (WezTerm zip, Neovim tar.gz)
- `fonts/` - JetBrainsMono Nerd Font (patched with icons)
- `config/` - Configuration files for all tools (designed for GNU Stow symlink management)

### Key Design Principles

1. **Zero Internet Dependency**: All binaries are static or self-contained, no package managers required
2. **Cross-Platform**: Same experience on macOS, regular Linux, and air-gapped Linux boxes
3. **Static Linking**: Linux binaries use musl static compilation to avoid glibc dependency issues
4. **Interactive Installation**: Smart version detection prevents accidental overwrites
5. **Beautiful UX**: Uses Charm Bracelet Gum for elegant TUI prompts when available
6. **Single Command Install**: `./install.sh` handles OS detection and full setup

### Binary Strategy

**Linux Packages:**
- Static tmux binary (no libevent dependency)
- Neovim static build extracted to `~/bin/`
- musl-static binaries for fd, ripgrep, bat (universal Linux compatibility)
- WezTerm AppImage (self-contained, no dependencies)
- Single-binary builds for fzf and starship

**macOS Packages:**
- WezTerm zip (extracts to `/Applications/`)
- Neovim ARM64 build (extracts to `/opt/homebrew/bin/`)
- Tools typically available via Homebrew on development machines

## GitHub Actions Automation

This repository includes a GitHub Actions workflow that automatically:
1. Downloads all binaries weekly (every Sunday at midnight UTC)
2. Bundles Neovim plugins using lazy.nvim
3. Creates GitHub releases with ready-to-deploy packages
4. Generates SHA256 checksums for verification

### Workflow Triggers

- **Scheduled**: Runs every Sunday at 00:00 UTC
- **Manual**: Click "Run workflow" in GitHub Actions tab
- **On Push**: Runs when workflow files or Neovim config changes

### What Gets Built

Each automated build creates:
- `airgap-dev-kit.tar.gz` - Complete kit with all binaries, configs, and plugins
- `checksums.txt` - SHA256 verification file
- GitHub Release with build notes and version info

### Using Automated Releases

```bash
# Download latest release from GitHub
wget https://github.com/YOUR_USERNAME/airgap-dev-kit/releases/latest/download/airgap-dev-kit.tar.gz
wget https://github.com/YOUR_USERNAME/airgap-dev-kit/releases/latest/download/checksums.txt

# Verify integrity
sha256sum -c checksums.txt

# Deploy to air-gapped machine
tar -xzf airgap-dev-kit.tar.gz
cd airgap-dev-kit
./install.sh
```

### How Plugin Bundling Works

The workflow:
1. Extracts the Linux Neovim binary from downloaded packages
2. Copies your `config/.config/nvim/` configuration
3. Runs `nvim --headless "+Lazy! sync" +qa` to download all plugins
4. Bundles `~/.local/share/nvim/lazy/` into the release
5. The `install.sh` script automatically extracts plugins on air-gapped machines

**Important**: Ensure your Neovim config in `config/.config/nvim/` has lazy.nvim configured with `install = { missing = false }` to prevent plugin auto-downloads on air-gapped systems.

## Installation Process

The `install.sh` script provides an interactive, intelligent installation experience:

### Features

1. **OS Detection**: Automatically detects macOS vs Linux
2. **Privilege Management**:
   - Detects if already running as root
   - Checks for passwordless sudo
   - Prompts for sudo password if needed
   - Falls back to `~/bin` if user declines sudo
3. **Version Checking**: Before overwriting existing binaries, shows:
   - Current installed version
   - New version being installed
   - Interactive prompt to confirm overwrite
4. **Beautiful TUI**: Uses [Charm Bracelet Gum](https://github.com/charmbracelet/gum) for elegant prompts with borders and styling
5. **Graceful Fallback**: If gum is not available, uses plain text prompts

### Installation Flow

```bash
./install.sh

# Step 1: OS Detection
Detecting OS...
Installing linux binaries...

# Step 2: Installation Location
Install system-wide to /usr/local/bin? (requires sudo) [Y/n]: y
Installing to: /usr/local/bin (system-wide)

# Step 3: Version Checking (if binary exists)
╭──────────────────────────────────────────╮
│ Found existing fzf at /usr/local/bin/fzf │
│   Current: 0.45.0                         │
│   New:     0.66.1                         │
╰──────────────────────────────────────────╯
Replace with new version? Yes

✓ fzf updated

# Step 4: Summary
✓ Installation complete!

📍 Installation Location:
   Binaries: /usr/local/bin
   Config: ~/.config/nvim/
   ...
```

### Smart Overwite Behavior

The installer will **never** silently overwrite existing binaries. For each tool that already exists:
- Extracts version information using `--version` or `-V` flags
- Displays current vs. new version
- Prompts for confirmation
- Allows skipping individual tools

This prevents accidentally downgrading or disrupting existing installations.

## Common Commands

### Quick Start with Makefile

The Makefile provides convenient targets for all common operations:

```bash
# Show all available commands and current status
make help

# Download all missing binaries (safe to re-run, skips existing files)
make update

# Verify all binaries are present and valid
make verify

# Create tarball for USB transfer to air-gapped machines
make package

# Install on current machine
make install

# Clean downloaded binaries but keep placeholders
make clean
```

### Initial Setup on Internet-Connected Machine

**Option 1: Using Makefile (recommended)**
```bash
# Download all missing binaries
make update

# Verify everything downloaded correctly
make verify

# Create deployment tarball
make package
# This creates: airgap-dev-kit.tar.gz (~250-350MB)
```

**Option 2: Manual download script**
Create a `download.sh` script to fetch all missing binaries:
```bash
#!/usr/bin/env bash
set -e

# Create directories
mkdir -p offline-packages/{linux,macos} fonts

# WezTerm (check latest release: https://github.com/wez/wezterm/releases)
curl -L https://github.com/wez/wezterm/releases/download/20230712-072601-f4abf8fd/WezTerm-macos-20230712-072601-f4abf8fd.zip \
  -o offline-packages/macos/WezTerm-macos.zip
curl -L https://github.com/wez/wezterm/releases/download/20230712-072601-f4abf8fd/WezTerm-20230712-072601-f4abf8fd-Ubuntu20.04.AppImage \
  -o offline-packages/linux/wezterm.AppImage

# Static tmux (v3.4)
curl -L https://github.com/nelsonenzo/tmux-static/releases/download/v3.4/tmux-3.4-static-x86_64 \
  -o offline-packages/linux/tmux-3.4-static-x86_64
chmod +x offline-packages/linux/tmux-3.4-static-x86_64

# Neovim nightly static builds
curl -L https://github.com/neovim/neovim/releases/download/nightly/nvim-linux64.tar.gz \
  -o offline-packages/linux/nvim-linux64.tar.gz
curl -L https://github.com/neovim/neovim/releases/download/nightly/nvim-macos-arm64.tar.gz \
  -o offline-packages/macos/nvim-macos-arm64.tar.gz

# fzf (fuzzy finder)
curl -L https://github.com/junegunn/fzf/releases/download/v0.55.0/fzf-0.55.0-linux_amd64.tar.gz | \
  tar -xz -C offline-packages/linux/
chmod +x offline-packages/linux/fzf

# fd, ripgrep, bat, lsd (already present or to be added)
# fd v10.2.0, ripgrep 14.1.1, bat v0.24.0 from musl static releases
# If updating, download from:
# fd: https://github.com/sharkdp/fd/releases
# rg: https://github.com/BurntSushi/ripgrep/releases
# bat: https://github.com/sharkdp/bat/releases
# lsd: https://github.com/lsd-rs/lsd/releases

# lsd (LSDeluxe) - modern ls replacement
curl -L https://github.com/lsd-rs/lsd/releases/download/v1.1.5/lsd-v1.1.5-x86_64-unknown-linux-musl.tar.gz | \
  tar -xz -C offline-packages/linux/ --strip-components=1
chmod +x offline-packages/linux/lsd

# Starship prompt (already present - v1.17+ recommended)
# If updating: https://github.com/starship/starship/releases
# curl -L https://github.com/starship/starship/releases/latest/download/starship-x86_64-unknown-linux-musl.tar.gz | \
#   tar -xz -C offline-packages/linux/

# JetBrainsMono Nerd Font (already present - 112MB)
# If updating: https://github.com/ryanoasis/nerd-fonts/releases
# curl -L https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/JetBrainsMono.zip \
#   -o fonts/JetBrainsMono.zip

echo "Download complete! Verify binaries:"
file offline-packages/linux/{wezterm.AppImage,tmux-3.4-static-x86_64,fzf,nvim-linux64.tar.gz}
file offline-packages/macos/{WezTerm-macos.zip,nvim-macos-arm64.tar.gz}
```

### Current Binary Status

**Already Present (verified working binaries):**
- ✅ `bat` (5.5M) - cat with syntax highlighting
- ✅ `fd` (3.9M) - modern find replacement
- ✅ `rg` (6.3M) - ripgrep for fast searching
- ✅ `starship` (12M) - cross-shell prompt
- ✅ `nvim-macos-arm64.tar.gz` (9.1M) - Neovim for macOS
- ✅ `JetBrainsMono.zip` (112M) - Nerd Font with icons

**Missing Core Binaries (placeholders - "Not Found" files):**
- ❌ `wezterm.AppImage` - Download from WezTerm releases
- ❌ `tmux-3.4-static-x86_64` - Download static build
- ❌ `nvim-linux64.tar.gz` - Download Linux Neovim
- ❌ `fzf` - Download fuzzy finder binary
- ❌ `WezTerm-macos.zip` - Download macOS version

**Optional Tools (not yet downloaded):**
- ⭕ `btop` - Beautiful system monitor (highly recommended!)
- ⭕ `eza` - Modern ls with colors and git status
- ⭕ `zoxide` - Smart directory jumper
- ⭕ `delta` - Better git diffs

Run `make update` to download all missing binaries including optional tools.

**Included Documentation/Completions:**
- Shell completions: `autocomplete/` (bash, zsh, fish for bat/fd)
- Man pages: `bat.1`, `fd.1`, `doc/rg.1`
- READMEs and licenses for each tool

### Deployment on Air-Gapped Machine

**Option 1: Using packaged tarball**
```bash
# Transfer airgap-dev-kit.tar.gz via USB to target machine
tar -xzf airgap-dev-kit.tar.gz
cd airgap-dev-kit
chmod +x install.sh
./install.sh
```

**Option 2: Direct folder transfer**
```bash
# Transfer entire airgap-dev-kit folder via USB/sneakernet
cd airgap-dev-kit
chmod +x install.sh
./install.sh
# Or use: make install
```

The installer will:
1. Detect OS (macOS vs Linux via `$OSTYPE`)
2. Copy binaries to `~/bin/` (Linux) or system locations (macOS)
3. Set executable permissions
4. Symlink configs using GNU Stow (expects `config/` to follow Stow directory structure)
5. Install fonts to `~/.local/share/fonts` (Linux) or open for manual install (macOS)

### Verify Installation

```bash
# Check binaries are accessible
which wezterm tmux nvim fzf fd rg bat lsd starship

# Test launches
~/bin/wezterm  # Linux
wezterm        # macOS (if ~/bin in PATH)
nvim --version
tmux -V
```

## Development Workflow

### Adding New Binaries

1. Download static/portable binary on internet-connected machine
2. Place in `offline-packages/linux/` or `offline-packages/macos/`
3. Update `install.sh` to copy/extract the binary:
   - For core tools: Add to the main copy line (around line 17)
   - For optional tools: Add a conditional check in the "Optional tools" section (around line 20)
4. For Linux: prefer musl-static builds for maximum compatibility
5. Test installation on clean machine to verify no missing dependencies

**Optional Tools Currently Supported** (auto-detected by install.sh):
- `lsd` - Modern ls with icons (recommended over eza for air-gap)
- `btop` - Beautiful resource monitor
- `eza` - Another modern ls (alternative to lsd)
- `zoxide` - Smarter cd command
- `delta` - Better git diff viewer

To add any of these, download the binary to `offline-packages/linux/` and the install script will automatically detect and install them.

**Example: Adding a new tool (e.g., `eza` as `ls` replacement)**
```makefile
# In Makefile, add to update-linux:
@echo "  → eza (modern ls)..."
@curl -fL "https://github.com/eza-community/eza/releases/latest/download/eza_x86_64-unknown-linux-musl.tar.gz" | \
	tar -xz -C offline-packages/linux/ eza
@chmod +x offline-packages/linux/eza
```

Then in `install.sh`:
```bash
cp offline-packages/linux/{nvim,fzf,fd,rg,bat,starship,eza} ~/bin/
```

### Updating Configurations

Configuration files should be organized for GNU Stow:
```
config/
├── .config/
│   ├── nvim/
│   │   └── init.lua
│   ├── wezterm/
│   │   └── wezterm.lua
│   └── starship.toml
└── .tmux.conf
```

**Note:** GNU Stow is optional. The installer will:
- Use `stow -t ~ config` if stow is available (creates symlinks)
- Otherwise, copy files directly to `~/.config/` (no symlinks)

Both methods work fine - symlinks are just easier to update.

### Updating Binary Versions

To update to newer versions of tools:

1. Edit version variables at top of `Makefile`:
```makefile
WEZTERM_VERSION := 20240101-120000-abcd1234
FZF_VERSION := 0.56.0
# etc.
```

2. Remove old binaries and re-download:
```bash
make clean
make update
make verify
```

3. Test on both macOS and Linux if possible
4. Create new package: `make package`

### Testing Installation Script

```bash
# Test on current machine
make install

# Test on macOS directly
./install.sh

# Test on Linux (use Docker for isolation)
docker run -it --rm -v $(pwd):/mnt ubuntu:22.04 bash
cd /mnt && apt-get update && apt-get install -y stow && ./install.sh

# Test Alpine Linux (minimal, tests static binary compatibility)
docker run -it --rm -v $(pwd):/mnt alpine:latest sh
cd /mnt && apk add stow && ./install.sh
```

## Important Notes

- **Placeholder Files**: Some files show "Not Found" content (9 bytes) - these are placeholders indicating binaries need to be downloaded using the download script
- **Font Installation**: macOS requires manual font installation (opens zip), Linux auto-installs via `fc-cache`
- **PATH Requirements**: Linux install assumes `~/bin` in PATH. Add to shell RC file if needed: `export PATH="$HOME/bin:$PATH"`
- **Stow Dependency**: `install.sh` calls `stow` command - ensure GNU Stow is pre-installed or add static build to offline-packages
- **Binary Sizes**: Current kit ~160MB, full kit with all binaries ~250-350MB. Use 1GB+ USB stick.
- **Shell Completions**: The kit includes completions for bash/zsh/fish in `offline-packages/linux/autocomplete/` and `complete/` - install manually if needed
- **Man Pages**: Offline documentation included as `.1` man page files - install to `/usr/local/share/man/man1/` for `man bat` etc.
- **macOS ARM64 Only**: Current Neovim package is ARM64. For Intel Macs, download x86_64 version separately.

## Configuration Integration

The kit assumes configs in `config/` directory will be managed by Stow, containing:
- `wezterm.lua` - Terminal emulator config (font, theme, keybindings)
- `tmux.conf` - Multiplexer settings (mouse support, pane navigation)
- `nvim/init.lua` - Editor config with lazy.nvim plugin manager
- `starship.toml` - Shell prompt configuration

## Air-Gap Neovim Plugin Strategy

Neovim plugins are the trickiest part of air-gapped setups since most plugin managers expect git/internet access. Here's the complete solution:

### Method 1: Bundle Pre-Downloaded Plugins (Recommended)

**Step 1: Set up Neovim config with lazy.nvim on internet machine**

Create `config/.config/nvim/init.lua`:
```lua
-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Plugin specifications
require("lazy").setup({
  -- Essential plugins for air-gap environment
  { "nvim-treesitter/nvim-treesitter", build = ":TSUpdate" },
  { "neovim/nvim-lspconfig" },
  { "hrsh7th/nvim-cmp" },              -- Autocompletion
  { "hrsh7th/cmp-nvim-lsp" },
  { "hrsh7th/cmp-buffer" },
  { "L3MON4D3/LuaSnip" },              -- Snippets
  { "catppuccin/nvim", name = "catppuccin" },  -- Theme
  { "nvim-lua/plenary.nvim" },         -- Required by many plugins
  { "nvim-telescope/telescope.nvim" }, -- Fuzzy finder
  { "tpope/vim-fugitive" },            -- Git integration
  { "lewis6991/gitsigns.nvim" },       -- Git signs in gutter
  { "windwp/nvim-autopairs" },         -- Auto close brackets
  { "numToStr/Comment.nvim" },         -- Easy commenting
}, {
  -- CRITICAL: Air-gap configuration
  install = {
    missing = false,  -- Don't auto-install missing plugins
  },
  checker = {
    enabled = false,  -- Disable update checking
  },
  change_detection = {
    enabled = false,  -- Don't watch for changes
  },
  performance = {
    cache = {
      enabled = true,
    },
  },
})

-- Theme
vim.cmd.colorscheme("catppuccin")

-- Basic settings
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
```

**Step 2: Download all plugins on internet machine**

```bash
# Install Neovim and open it (lazy.nvim will auto-install plugins)
nvim

# Or headless install
nvim --headless "+Lazy! sync" +qa

# Verify installations
ls -la ~/.local/share/nvim/lazy/
# Should show: lazy.nvim, nvim-treesitter, nvim-lspconfig, etc.

# Also check data files
ls -la ~/.local/share/nvim/
# Should show: lazy/ (plugins), lazy-lock.json (version lock)
```

**Step 3: Bundle plugins into the kit**

```bash
# Create plugins archive
cd ~/.local/share/nvim
tar -czf lazy-plugins.tar.gz lazy/ lazy-lock.json

# Move to kit
mv lazy-plugins.tar.gz ~/airgap-dev-kit/offline-packages/

# Also bundle the config
cd ~/airgap-dev-kit
mkdir -p config/.config/nvim
cp -r ~/.config/nvim/* config/.config/nvim/
```

**Step 4: Add plugin extraction to install.sh**

Add this section to `install.sh` after the binary installation:

```bash
# Install Neovim plugins (if archive exists)
if [[ -f offline-packages/lazy-plugins.tar.gz ]]; then
  echo "Installing Neovim plugins..."
  mkdir -p ~/.local/share/nvim
  tar -xzf offline-packages/lazy-plugins.tar.gz -C ~/.local/share/nvim/
  echo "✓ Neovim plugins installed"
fi
```

**Step 5: On air-gapped machine**

```bash
./install.sh  # Installs everything including plugins
nvim          # Should work immediately with all plugins
```

### Method 2: Bundle Plugins Directly in Config (Alternative)

Place plugins directly in the config directory structure:

```bash
# Structure
config/
├── .config/
│   └── nvim/
│       ├── init.lua
│       └── pack/
│           └── vendor/
│               └── start/
│                   ├── lazy.nvim/
│                   ├── nvim-treesitter/
│                   ├── nvim-lspconfig/
│                   └── ...

# Modify init.lua to use this location
local lazypath = vim.fn.stdpath("config") .. "/pack/vendor/start/lazy.nvim"
vim.opt.rtp:prepend(lazypath)
```

This way Stow will symlink everything including plugins. **Downside**: Larger config directory, harder to update.

### Method 3: Git Bundle (For Version Control)

If you want to keep plugins under version control:

```bash
# On internet machine
cd ~/.local/share/nvim/lazy/nvim-treesitter
git bundle create treesitter.bundle --all

# Transfer bundle files, then on air-gap:
git clone treesitter.bundle nvim-treesitter
```

**This is tedious for many plugins** - Method 1 is easier.

### Handling LSP Servers (Language Servers)

LSP servers are separate from plugins and need special handling:

**Step 1: Download LSP servers on internet machine**

```bash
# Using mason.nvim (LSP installer) - NOT recommended for air-gap
# Instead, download static LSP binaries manually

mkdir -p airgap-dev-kit/offline-packages/lsp-servers

# Example: lua-language-server
curl -L https://github.com/LuaLS/lua-language-server/releases/download/3.7.4/lua-language-server-3.7.4-linux-x64.tar.gz \
  -o lsp-servers/lua-language-server.tar.gz

# Example: pyright (Python)
npm install -g pyright
# Then copy from npm global: ~/.npm-global/lib/node_modules/pyright

# Example: rust-analyzer
curl -L https://github.com/rust-lang/rust-analyzer/releases/latest/download/rust-analyzer-x86_64-unknown-linux-gnu.gz \
  | gunzip > lsp-servers/rust-analyzer
chmod +x lsp-servers/rust-analyzer
```

**Step 2: Configure LSP without mason.nvim**

In `init.lua` or `config/.config/nvim/lua/lsp.lua`:

```lua
local lspconfig = require('lspconfig')

-- Point to bundled LSP servers
local lsp_bin = vim.fn.expand("~/bin/lsp/")

lspconfig.lua_ls.setup({
  cmd = { lsp_bin .. "lua-language-server" },
})

lspconfig.pyright.setup({
  cmd = { lsp_bin .. "pyright-langserver", "--stdio" },
})

lspconfig.rust_analyzer.setup({
  cmd = { lsp_bin .. "rust-analyzer" },
})
```

**Step 3: Install LSP servers in install.sh**

```bash
# Add to install.sh
echo "Installing LSP servers..."
mkdir -p ~/bin/lsp
if [[ -d offline-packages/lsp-servers ]]; then
  cp offline-packages/lsp-servers/* ~/bin/lsp/
  chmod +x ~/bin/lsp/*
fi
```

### Treesitter Parsers (Syntax Highlighting)

Treesitter needs compiled parsers for each language:

**Step 1: Pre-compile parsers on internet machine**

```lua
-- In init.lua
require('nvim-treesitter.configs').setup({
  ensure_installed = { "lua", "python", "rust", "bash", "json", "yaml" },
  highlight = { enable = true },
})
```

```bash
# Open Neovim and compile
nvim "+TSInstall lua python rust bash" +qa

# Parsers are stored in ~/.local/share/nvim/lazy/nvim-treesitter/parser/
ls ~/.local/share/nvim/lazy/nvim-treesitter/parser/
# Should see: lua.so, python.so, rust.so, etc.
```

**These are bundled automatically** when you tar the `lazy/` directory in Method 1.

### Testing Plugin Setup

On air-gapped machine after installation:

```bash
# Check Neovim can find plugins
nvim --version
nvim -c 'lua print(vim.fn.stdpath("data") .. "/lazy")' -c 'qa'

# List installed plugins
nvim -c 'Lazy' -c 'qa'

# Test LSP
nvim test.lua
# In Neovim: :LspInfo should show lua_ls attached

# Test Treesitter
nvim test.py
# Should see syntax highlighting
# :TSInstallInfo to verify parsers
```

### Minimal Air-Gap Neovim Config

If you want the absolute minimum without complex plugin managers:

```lua
-- init.lua - no plugin manager, just vim-plug style
local plugins_path = vim.fn.stdpath("config") .. "/plugins"
vim.opt.runtimepath:append(plugins_path .. "/nvim-treesitter")
vim.opt.runtimepath:append(plugins_path .. "/nvim-lspconfig")
-- ... manually add each plugin

-- Then just copy plugin git repos directly to plugins/
```

**Recommendation**: Stick with **Method 1 (lazy.nvim with bundled plugins)** - it's the most maintainable and follows standard Neovim practices.

## Advanced Usage

### Installing Shell Completions

```bash
# Bash (add to ~/.bashrc)
source ~/bin/../offline-packages/linux/autocomplete/bat.bash
source ~/bin/../offline-packages/linux/autocomplete/fd.bash
source ~/bin/../offline-packages/linux/complete/rg.bash

# Zsh (add to ~/.zshrc)
fpath=(~/offline-packages/linux/autocomplete $fpath)
autoload -Uz compinit && compinit

# Fish
mkdir -p ~/.config/fish/completions
cp offline-packages/linux/autocomplete/*.fish ~/.config/fish/completions/
```

### Installing Man Pages

```bash
# System-wide (requires sudo)
sudo mkdir -p /usr/local/share/man/man1
sudo cp offline-packages/linux/{bat.1,fd.1,doc/rg.1} /usr/local/share/man/man1/
sudo mandb  # Linux
# macdb      # macOS (if needed)

# User-local (no sudo)
mkdir -p ~/.local/share/man/man1
cp offline-packages/linux/{bat.1,fd.1,doc/rg.1} ~/.local/share/man/man1/
export MANPATH="$HOME/.local/share/man:$MANPATH"
```

### Pre-bundling Neovim Plugins

To avoid plugin installation on air-gapped machines:

```bash
# On internet machine, after setting up Neovim config with lazy.nvim
nvim --headless "+Lazy! sync" +qa

# Bundle plugin directory
tar -czf nvim-plugins.tar.gz -C ~/.local/share/nvim/site/pack/lazy/ .

# Copy to kit
mv nvim-plugins.tar.gz airgap-dev-kit/

# On air-gapped machine (add to install.sh or run manually)
mkdir -p ~/.local/share/nvim/site/pack/lazy/
tar -xzf nvim-plugins.tar.gz -C ~/.local/share/nvim/site/pack/lazy/
```

### Creating a Bootstrap Script

For completely fresh systems, create `bootstrap.sh`:

```bash
#!/usr/bin/env bash
# Pre-install dependencies that install.sh needs

set -e

if [[ "$OSTYPE" == "darwin"* ]]; then
  echo "macOS detected - ensuring Command Line Tools..."
  xcode-select --install 2>/dev/null || true

  # Install Stow if not present
  if ! command -v stow &>/dev/null; then
    echo "Installing Stow via Homebrew (requires internet)..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    brew install stow
  fi
else
  echo "Linux detected - installing Stow..."
  # Debian/Ubuntu
  if command -v apt-get &>/dev/null; then
    sudo apt-get update && sudo apt-get install -y stow
  # RHEL/CentOS/Fedora
  elif command -v dnf &>/dev/null; then
    sudo dnf install -y stow
  elif command -v yum &>/dev/null; then
    sudo yum install -y stow
  # Arch
  elif command -v pacman &>/dev/null; then
    sudo pacman -S --noconfirm stow
  else
    echo "Unknown package manager - install stow manually"
    exit 1
  fi
fi

echo "Bootstrap complete! Run ./install.sh"
```

### Packaging for Transfer

```bash
# Create distributable archive (run from parent directory)
tar -czf airgap-dev-kit.tar.gz airgap-dev-kit/
# Or zip for Windows compatibility
zip -r airgap-dev-kit.zip airgap-dev-kit/

# Verify archive
tar -tzf airgap-dev-kit.tar.gz | head -20
```

### Upgrading Binaries

```bash
# Check current versions
~/bin/bat --version
~/bin/fd --version
~/bin/rg --version
~/bin/nvim --version

# To upgrade: download new versions on internet machine
# Replace binaries in offline-packages/{linux,macos}/
# Re-run install.sh on air-gapped machine
```

## Tool Usage Examples

After installation, set up shell aliases and integrations:

### btop - System Monitor
```bash
# Just run it - replaces top/htop with beautiful TUI
btop

# Keybindings:
# q - quit
# m - toggle between different views
# ESC - back to main menu
```

### eza - Modern ls
```bash
# Add to .bashrc/.zshrc:
alias ls='eza --icons'
alias ll='eza -l --icons --git'
alias la='eza -la --icons --git'
alias tree='eza --tree --icons'
```

### zoxide - Smart cd
```bash
# Initialize in shell (add to .bashrc/.zshrc):
eval "$(zoxide init bash)"  # or zsh, fish, etc.

# Usage:
z project     # Jump to most-used directory matching "project"
zi project    # Interactive selection with fzf
z -          # Go back to previous directory
```

### delta - Better git diff
```bash
# Configure in ~/.gitconfig:
[core]
    pager = delta

[interactive]
    diffFilter = delta --color-only

[delta]
    navigate = true
    side-by-side = true
    line-numbers = true
```

### fzf Integration
```bash
# Add to .bashrc/.zshrc for better defaults:
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_DEFAULT_OPTS='--height 40% --border'

# Use with bat for preview:
alias preview='fzf --preview="bat --color=always {}"'
```

## Troubleshooting

**Binary Not Found Errors**: Verify all placeholder files replaced with actual binaries before deployment. Check with: `file offline-packages/linux/* offline-packages/macos/*`

**Permission Denied**: Ensure `chmod +x` applied to all binaries after extraction. Fix with: `chmod +x ~/bin/*`

**Missing Dependencies**: If Linux binary fails with library errors, replace with musl-static variant. Verify with: `ldd ~/bin/binary` (should say "not a dynamic executable")

**Stow Conflicts**: If symlinks fail, check for existing files in `~/`. Use `stow -D config` to remove old symlinks, backup conflicts, then re-run.

**macOS Gatekeeper**: WezTerm may require: `xattr -cr /Applications/WezTerm.app` to bypass security warnings. Alternatively: System Settings → Privacy & Security → Allow.

**tmux UTF-8 Issues**: If seeing garbled characters, ensure `LANG=en_US.UTF-8` in shell profile.

**Neovim Plugin Errors**: If lazy.nvim tries to git clone, ensure `install = { missing = false }` in lazy setup and plugins are pre-bundled.

**Font Not Detected**: After installation, restart terminal and verify with: `fc-list | grep JetBrains` (Linux) or Font Book (macOS).

**PATH Not Updated**: Add to `~/.bashrc`, `~/.zshrc`, or `~/.profile`: `export PATH="$HOME/bin:$PATH"` then source the file or restart shell.

**WezTerm AppImage Won't Run**: Ensure FUSE is available on Linux: `sudo apt-get install fuse libfuse2` or extract AppImage: `./wezterm.AppImage --appimage-extract` then use `squashfs-root/usr/bin/wezterm`.

## Security Considerations

- **Verify Downloads**: Check SHA256 hashes from official GitHub releases before bundling
- **Virus Scan**: Run binaries through antivirus before transferring to air-gapped environments
- **Read-Only Media**: Use write-protected USB or CD/DVD for transfer to prevent contamination
- **Binary Integrity**: Consider signing the archive with GPG for additional validation
- **Network Isolation**: Verify air-gapped machine has no network interfaces before installation
- **Audit Trail**: Log all installations with timestamps for compliance: `./install.sh 2>&1 | tee install-$(date +%Y%m%d-%H%M%S).log`

## Recommended Workflow

1. **Prepare Kit** (Internet Machine):
   - Clone/download this repository
   - Run download script to fetch missing binaries
   - Set up `config/` directory with your dotfiles
   - Pre-download Neovim plugins
   - Create archive: `tar -czf airgap-dev-kit.tar.gz airgap-dev-kit/`

2. **Transfer**:
   - Copy archive to USB drive
   - Verify checksum: `sha256sum airgap-dev-kit.tar.gz > checksum.txt`

3. **Deploy** (Air-Gapped Machine):
   - Extract: `tar -xzf airgap-dev-kit.tar.gz`
   - Verify: `cd airgap-dev-kit && file offline-packages/linux/*`
   - Install: `./install.sh`
   - Test: `~/bin/wezterm start -- ~/bin/tmux new-session ~/bin/nvim`

4. **Customize**:
   - Edit configs in `~/.config/` (symlinked by Stow)
   - Add aliases to `~/.bashrc` or `~/.zshrc`
   - Set up starship: `eval "$(~/bin/starship init bash)"`

## Additional Resources

**Useful Aliases** (add to shell RC):
```bash
# Use modern CLI tools
alias ls='lsd'                      # Or 'eza' if you prefer
alias ll='lsd -lah'                 # Long listing with icons
alias lt='lsd --tree'               # Tree view
alias cat='bat --paging=never'      # Syntax-highlighted cat
alias find='fd'                     # Faster find
alias grep='rg'                     # Faster grep

# Traditional fallbacks (if lsd not available)
# alias ls='ls --color=auto'
# alias ll='ls -lah'
```

**lsd vs eza**: Both are modern `ls` replacements written in Rust with icons and colors.
- **lsd** (LSDeluxe): Simpler, faster, static binary available
- **eza**: More features, active development, but requires libc

For air-gap environments, **lsd is recommended** due to easier static compilation.

**Starship Configuration**:
Place `starship.toml` in `~/.config/` or `config/.config/` for Stow:
```toml
format = "$username$hostname$directory$git_branch$character"
[character]
success_symbol = "[➜](bold green)"
error_symbol = "[✗](bold red)"
```

**Tmux Key Bindings** (add to `~/.tmux.conf`):
```bash
# Reload config
bind r source-file ~/.tmux.conf \; display "Reloaded!"

# Better pane splitting
bind | split-window -h
bind - split-window -v
```

**Expected Directory Structure After Installation**:
```
~/
├── bin/
│   ├── wezterm         # Terminal emulator
│   ├── tmux            # Multiplexer
│   ├── nvim            # Editor
│   ├── fzf             # Fuzzy finder
│   ├── fd              # File finder
│   ├── rg              # Grep replacement
│   ├── bat             # Cat replacement
│   ├── lsd             # Modern ls (with icons)
│   └── starship        # Prompt
├── .config/
│   ├── nvim/           # Neovim config (via Stow)
│   ├── wezterm/        # WezTerm config (via Stow)
│   └── starship.toml   # Prompt config (via Stow)
├── .tmux.conf          # Tmux config (via Stow)
└── .local/
    └── share/
        ├── fonts/      # JetBrainsMono Nerd Font
        └── nvim/       # Neovim plugins/data
```
