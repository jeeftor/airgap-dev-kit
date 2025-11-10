#!/usr/bin/env bash
set -e

echo "Detecting OS..."
if [[ "$OSTYPE" == "darwin"* ]]; then
  OS="macos"
else
  OS="linux"
fi

echo "Installing $OS binaries..."

# Determine install location - prefer system dirs if we have sudo, otherwise use ~/bin
if [[ $EUID -eq 0 ]] || sudo -n true 2>/dev/null; then
  BIN_DIR="/usr/local/bin"
  echo "Installing to: $BIN_DIR (system-wide)"
  USE_SUDO="sudo"
else
  BIN_DIR="$HOME/bin"
  echo "Installing to: $BIN_DIR (user-local, no sudo available)"
  echo "Note: Add $BIN_DIR to PATH or re-run with sudo for system-wide install"
  USE_SUDO=""
fi

$USE_SUDO mkdir -p "$BIN_DIR"

if [[ $OS == "linux" ]]; then
  # Check if we have linux binaries
  if [[ ! -d offline-packages/linux ]]; then
    echo "Error: Linux binaries not found. Did you download the macOS package by mistake?"
    exit 1
  fi

  $USE_SUDO cp offline-packages/linux/wezterm.AppImage "$BIN_DIR/wezterm"
  $USE_SUDO cp offline-packages/linux/tmux-3.4-static-x86_64 "$BIN_DIR/tmux"
  $USE_SUDO cp offline-packages/linux/{fzf,fd,rg,bat,starship} "$BIN_DIR/"

  # Optional tools (skip if not present)
  [ -f offline-packages/linux/lsd ] && $USE_SUDO cp offline-packages/linux/lsd "$BIN_DIR/"
  [ -f offline-packages/linux/btop ] && $USE_SUDO cp offline-packages/linux/btop "$BIN_DIR/"
  [ -f offline-packages/linux/eza ] && $USE_SUDO cp offline-packages/linux/eza "$BIN_DIR/"
  [ -f offline-packages/linux/zoxide ] && $USE_SUDO cp offline-packages/linux/zoxide "$BIN_DIR/"
  [ -f offline-packages/linux/delta ] && $USE_SUDO cp offline-packages/linux/delta "$BIN_DIR/"

  $USE_SUDO chmod +x "$BIN_DIR"/*

  # Extract Neovim to /opt (or ~/ if no sudo)
  if [[ -f offline-packages/linux/nvim-linux64.tar.gz ]]; then
    if [[ -n "$USE_SUDO" ]]; then
      $USE_SUDO tar -xzf offline-packages/linux/nvim-linux64.tar.gz -C /opt/
      $USE_SUDO ln -sf /opt/nvim-linux-x86_64/bin/nvim "$BIN_DIR/nvim"
    else
      tar -xzf offline-packages/linux/nvim-linux64.tar.gz -C ~/
      ln -sf ~/nvim-linux-x86_64/bin/nvim "$BIN_DIR/nvim"
    fi
  else
    echo "Warning: Neovim tarball not found in offline-packages/linux/"
  fi
else
  # Check if we have macOS binaries
  if [[ ! -d offline-packages/macos ]]; then
    echo "Error: macOS binaries not found. Did you download the Linux package by mistake?"
    exit 1
  fi

  unzip -q offline-packages/macos/WezTerm-macos.zip -d /Applications/
  tar -xzf offline-packages/macos/nvim-macos-arm64.tar.gz -C /tmp/
  $USE_SUDO mkdir -p "$BIN_DIR"
  $USE_SUDO cp /tmp/nvim-macos-arm64/bin/nvim "$BIN_DIR/"
  rm -rf /tmp/nvim-macos-arm64
fi

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
echo "📍 Installation Location:"
echo "   Binaries: $BIN_DIR"
if [[ -n "$USE_SUDO" ]]; then
  echo "   Neovim: /opt/nvim-linux-x86_64/ (symlinked to $BIN_DIR/nvim)"
else
  echo "   Neovim: ~/nvim-linux-x86_64/bin/nvim (symlinked to $BIN_DIR/nvim)"
fi
echo "   Config: ~/.config/nvim/"
echo "   Fonts: ~/.local/share/fonts/ (Linux) or /Applications/Font Book (macOS)"
echo ""
echo "📋 Next Steps:"
echo ""
if [[ "$BIN_DIR" == "$HOME/bin" ]]; then
  echo "1. Add tools to your PATH (add to ~/.bashrc or ~/.zshrc):"
  echo "   export PATH=\"\$HOME/bin:\$PATH\""
  echo ""
  echo "2. Source your profile or restart shell:"
  echo "   source ~/.bashrc  # or ~/.zshrc"
else
  echo "1. Tools installed to $BIN_DIR (already in PATH ✓)"
  echo ""
  echo "2. Optionally set up aliases in ~/.bashrc or ~/.zshrc"
  echo "   See: shell-setup-example.sh"
fi
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
if [[ -n "$DISPLAY" || "$OSTYPE" == "darwin"* ]]; then
  echo "   wezterm start -- tmux new-session nvim  # GUI environment"
else
  echo "   tmux new-session nvim  # Headless/SSH (WezTerm requires GUI)"
fi
echo ""
echo "📚 Installed tools:"
if [[ -n "$DISPLAY" || "$OSTYPE" == "darwin"* ]]; then
  echo "   Terminal: wezterm (GUI), tmux (multiplexer)"
else
  echo "   Terminal: tmux (multiplexer)"
  echo "   Note: WezTerm installed but requires GUI (use on desktop)"
fi
echo "   Editor: nvim (with plugins)"
echo "   CLI Tools: fzf, fd, rg, bat, starship"
if [[ -f ~/bin/lsd ]]; then echo "   Optional: lsd"; fi
if [[ -f ~/bin/btop ]]; then echo "   Optional: btop"; fi
if [[ -f ~/bin/eza ]]; then echo "   Optional: eza"; fi
if [[ -f ~/bin/zoxide ]]; then echo "   Optional: zoxide"; fi
if [[ -f ~/bin/delta ]]; then echo "   Optional: delta"; fi
echo ""
echo "💡 Tips:"
echo "   - Use 'fzf' for fuzzy file finding (Ctrl+R for history)"
echo "   - Use 'fd <pattern>' instead of 'find'"
echo "   - Use 'rg <pattern>' instead of 'grep'"
if [[ -f ~/bin/btop ]]; then
  echo "   - Run 'btop' for system monitoring"
fi
if [[ -f ~/bin/zoxide ]]; then
  echo "   - After setup, use 'z <dir>' to jump to directories"
fi
if [[ -z "$DISPLAY" && "$OSTYPE" != "darwin"* ]]; then
  echo ""
  echo "🔌 SSH/Headless Environment Detected:"
  echo "   - tmux is your friend: 'tmux new -s work'"
  echo "   - Create splits: Ctrl+b % (vertical) or Ctrl+b \" (horizontal)"
  echo "   - Navigate panes: Ctrl+b <arrow keys>"
  echo "   - Detach: Ctrl+b d, Reattach: 'tmux attach'"
  echo "   - See shell-setup-example.sh for more tips"
fi
echo ""