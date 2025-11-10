#!/usr/bin/env bash
set -e

echo "Detecting OS..."
if [[ "$OSTYPE" == "darwin"* ]]; then
  OS="macos"
else
  OS="linux"
fi

echo "Installing $OS binaries..."
mkdir -p ~/bin

if [[ $OS == "linux" ]]; then
  cp offline-packages/linux/wezterm.AppImage ~/bin/wezterm
  cp offline-packages/linux/tmux-3.4-static-x86_64 ~/bin/tmux
  cp offline-packages/linux/{fzf,fd,rg,bat,starship} ~/bin/

  # Optional tools (skip if not present)
  [ -f offline-packages/linux/lsd ] && cp offline-packages/linux/lsd ~/bin/
  [ -f offline-packages/linux/btop ] && cp offline-packages/linux/btop ~/bin/
  [ -f offline-packages/linux/eza ] && cp offline-packages/linux/eza ~/bin/
  [ -f offline-packages/linux/zoxide ] && cp offline-packages/linux/zoxide ~/bin/
  [ -f offline-packages/linux/delta ] && cp offline-packages/linux/delta ~/bin/

  tar -xzf offline-packages/linux/nvim-linux64.tar.gz -C ~/
else
  unzip offline-packages/macos/WezTerm-macos.zip -d /Applications/
  tar -xzf offline-packages/macos/nvim-macos-arm64.tar.gz -C /opt/homebrew/bin/ --strip-components=1
fi

chmod +x ~/bin/*

# Install Neovim plugins (if bundled)
if [[ -f offline-packages/lazy-plugins.tar.gz ]]; then
  echo "Installing Neovim plugins..."
  mkdir -p ~/.local/share/nvim
  tar -xzf offline-packages/lazy-plugins.tar.gz -C ~/.local/share/nvim/
  echo "✓ Neovim plugins installed"
fi

# Symlink configs
stow -t ~ config

# Fonts
if [[ $OS == "macos" ]]; then
  open fonts/JetBrainsMono.zip
else
  mkdir -p ~/.local/share/fonts
  unzip -o fonts/JetBrainsMono.zip -d ~/.local/share/fonts
  fc-cache -fv
fi

echo "Done! Launch with: ~/bin/wezterm"