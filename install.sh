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
  # Check if we have linux binaries
  if [[ ! -d offline-packages/linux ]]; then
    echo "Error: Linux binaries not found. Did you download the macOS package by mistake?"
    exit 1
  fi

  cp offline-packages/linux/wezterm.AppImage ~/bin/wezterm
  cp offline-packages/linux/tmux-3.4-static-x86_64 ~/bin/tmux
  cp offline-packages/linux/{fzf,fd,rg,bat,starship} ~/bin/

  # Optional tools (skip if not present)
  [ -f offline-packages/linux/lsd ] && cp offline-packages/linux/lsd ~/bin/
  [ -f offline-packages/linux/btop ] && cp offline-packages/linux/btop ~/bin/
  [ -f offline-packages/linux/eza ] && cp offline-packages/linux/eza ~/bin/
  [ -f offline-packages/linux/zoxide ] && cp offline-packages/linux/zoxide ~/bin/
  [ -f offline-packages/linux/delta ] && cp offline-packages/linux/delta ~/bin/

  # Extract Neovim - handle both possible locations
  if [[ -f offline-packages/linux/nvim-linux64.tar.gz ]]; then
    tar -xzf offline-packages/linux/nvim-linux64.tar.gz -C ~/
  else
    echo "Warning: Neovim tarball not found in offline-packages/linux/"
  fi
else
  # Check if we have macOS binaries
  if [[ ! -d offline-packages/macos ]]; then
    echo "Error: macOS binaries not found. Did you download the Linux package by mistake?"
    exit 1
  fi

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

# Install configs
if command -v stow &>/dev/null && [[ -d config ]]; then
  echo "Symlinking configs with stow..."
  stow -t ~ config
elif [[ -d config ]]; then
  echo "Installing configs (copying)..."
  # Copy config files directly (stow not available)
  if [[ -d config/.config ]]; then
    mkdir -p ~/.config
    cp -r config/.config/* ~/.config/
  fi
  # Copy other dotfiles if they exist
  for file in config/.*; do
    [[ -f "$file" ]] && cp "$file" ~/
  done
  echo "✓ Configs installed"
else
  echo "⚠ No config directory found, skipping config installation"
fi

# Fonts
if [[ $OS == "macos" ]]; then
  open fonts/JetBrainsMono.zip
else
  mkdir -p ~/.local/share/fonts
  unzip -o fonts/JetBrainsMono.zip -d ~/.local/share/fonts
  fc-cache -fv
fi

echo ""
echo "=========================================="
echo "✓ Installation complete!"
echo "=========================================="
echo ""
echo "📋 Next Steps:"
echo ""
echo "1. Add tools to your PATH (add to ~/.bashrc or ~/.zshrc):"
echo "   export PATH=\"\$HOME/bin:\$PATH\""
echo ""
echo "2. Source your profile or restart shell:"
echo "   source ~/.bashrc  # or ~/.zshrc"
echo ""
echo "3. Optional: Set up aliases in ~/.bashrc or ~/.zshrc:"
if [[ -f ~/bin/lsd ]]; then
  echo "   alias ls='lsd'"
  echo "   alias ll='lsd -la'"
  echo "   alias tree='lsd --tree'"
fi
if [[ -f ~/bin/bat ]]; then
  echo "   alias cat='bat --paging=never'"
fi
if [[ -f ~/bin/zoxide ]]; then
  echo "   eval \"\$(zoxide init bash)\"  # or zsh, fish"
fi
if [[ -f ~/bin/starship ]]; then
  echo "   eval \"\$(starship init bash)\"  # or zsh, fish"
fi
echo ""
echo "4. Launch your environment:"
echo "   wezterm start -- tmux new-session nvim"
echo ""
echo "📚 Installed tools:"
echo "   Core: wezterm, tmux, nvim, fzf, fd, rg, bat, starship"
if [[ -f ~/bin/lsd ]]; then echo "   Optional: lsd"; fi
if [[ -f ~/bin/btop ]]; then echo "   Optional: btop"; fi
if [[ -f ~/bin/eza ]]; then echo "   Optional: eza"; fi
if [[ -f ~/bin/zoxide ]]; then echo "   Optional: zoxide"; fi
if [[ -f ~/bin/delta ]]; then echo "   Optional: delta"; fi
echo ""
echo "💡 Tips:"
echo "   - Use 'fzf' for fuzzy file finding"
echo "   - Use 'fd <pattern>' instead of 'find'"
echo "   - Use 'rg <pattern>' instead of 'grep'"
if [[ -f ~/bin/btop ]]; then
  echo "   - Run 'btop' for system monitoring"
fi
if [[ -f ~/bin/zoxide ]]; then
  echo "   - After setup, use 'z <dir>' to jump to directories"
fi
echo ""