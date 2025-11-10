#!/usr/bin/env bash
set -e

# Helper function to check if gum is available (for pretty TUI prompts)
has_gum() {
  command -v gum &>/dev/null || [ -f "$PWD/offline-packages/linux/gum" ] || [ -f "$PWD/offline-packages/macos/gum" ]
}

# Helper function to get version from binary
get_version() {
  local binary="$1"
  local version_flag="${2:---version}"

  if [[ ! -f "$binary" ]]; then
    echo "not-installed"
    return
  fi

  # Try to extract version, handle various formats
  local version=$("$binary" "$version_flag" 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1 || echo "unknown")
  echo "$version"
}

# Helper function to prompt for overwrite
prompt_overwrite() {
  local tool_name="$1"
  local existing_version="$2"
  local new_version="$3"
  local install_path="$4"

  if [[ "$existing_version" == "unknown" ]]; then
    existing_version="(version unknown)"
  fi

  if [[ "$new_version" == "unknown" ]]; then
    new_version="(version unknown)"
  fi

  if has_gum; then
    # Use gum for pretty prompts if available
    local GUM="${BIN_DIR}/gum"
    [[ ! -f "$GUM" ]] && GUM="$PWD/offline-packages/$OS/gum"

    echo ""
    $GUM style --border rounded --padding "0 1" --margin "1 0" \
      "Found existing $tool_name at $install_path" \
      "  Current: $existing_version" \
      "  New:     $new_version"

    if $GUM confirm "Replace with new version?"; then
      return 0  # User said yes
    else
      return 1  # User said no
    fi
  else
    # Fallback to regular prompt
    echo ""
    echo "Found existing $tool_name:"
    echo "  Location: $install_path"
    echo "  Current version: $existing_version"
    echo "  New version: $new_version"
    read -p "Replace with new version? [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      return 0  # User said yes
    else
      return 1  # User said no
    fi
  fi
}

echo "Detecting OS..."
if [[ "$OSTYPE" == "darwin"* ]]; then
  OS="macos"
else
  OS="linux"
fi

echo "Installing $OS binaries..."

# Determine install location - prefer system dirs if we have sudo, otherwise use ~/bin
if [[ $EUID -eq 0 ]]; then
  # Already running as root
  BIN_DIR="/usr/local/bin"
  echo "Installing to: $BIN_DIR (system-wide)"
  USE_SUDO=""
elif sudo -n true 2>/dev/null; then
  # Can sudo without password
  BIN_DIR="/usr/local/bin"
  echo "Installing to: $BIN_DIR (system-wide)"
  USE_SUDO="sudo"
else
  # Try to prompt for sudo password
  echo ""
  echo "This installer can install to /usr/local/bin (recommended) or ~/bin"
  echo ""
  read -p "Install system-wide to /usr/local/bin? (requires sudo) [Y/n]: " -n 1 -r
  echo

  if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
    # User wants system-wide install, prompt for sudo
    if sudo -v; then
      BIN_DIR="/usr/local/bin"
      echo "Installing to: $BIN_DIR (system-wide)"
      USE_SUDO="sudo"
      # Keep sudo alive in background
      while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
    else
      echo "Sudo authentication failed. Falling back to user install."
      BIN_DIR="$HOME/bin"
      echo "Installing to: $BIN_DIR (user-local)"
      USE_SUDO=""
    fi
  else
    # User chose user install
    BIN_DIR="$HOME/bin"
    echo "Installing to: $BIN_DIR (user-local)"
    echo "Note: You'll need to add this to your PATH"
    USE_SUDO=""
  fi
fi

echo ""

$USE_SUDO mkdir -p "$BIN_DIR"

# Install gum first (so we can use it for prompts)
if [[ -f offline-packages/$OS/gum ]]; then
  if [[ -f "$BIN_DIR/gum" ]]; then
    existing_ver=$(get_version "$BIN_DIR/gum")
    new_ver=$(get_version "offline-packages/$OS/gum")
    if prompt_overwrite "gum" "$existing_ver" "$new_ver" "$BIN_DIR/gum"; then
      $USE_SUDO cp offline-packages/$OS/gum "$BIN_DIR/"
      $USE_SUDO chmod +x "$BIN_DIR/gum"
      echo "✓ gum installed"
    else
      echo "⊘ Skipped gum"
    fi
  else
    $USE_SUDO cp offline-packages/$OS/gum "$BIN_DIR/"
    $USE_SUDO chmod +x "$BIN_DIR/gum"
    echo "✓ gum installed"
  fi
fi

# Helper function to install binary with version check
install_binary() {
  local source_file="$1"
  local dest_name="$2"
  local tool_name="$3"
  local version_flag="${4:---version}"

  if [[ ! -f "$source_file" ]]; then
    return  # Skip if source doesn't exist
  fi

  local dest_path="$BIN_DIR/$dest_name"

  if [[ -f "$dest_path" ]]; then
    # Binary exists, check version
    local existing_ver=$(get_version "$dest_path" "$version_flag")
    local new_ver=$(get_version "$source_file" "$version_flag")

    if prompt_overwrite "$tool_name" "$existing_ver" "$new_ver" "$dest_path"; then
      $USE_SUDO cp "$source_file" "$dest_path"
      $USE_SUDO chmod +x "$dest_path"
      echo "✓ $tool_name updated"
    else
      echo "⊘ Skipped $tool_name"
    fi
  else
    # Fresh install
    $USE_SUDO cp "$source_file" "$dest_path"
    $USE_SUDO chmod +x "$dest_path"
    echo "✓ $tool_name installed"
  fi
}

if [[ $OS == "linux" ]]; then
  # Check if we have linux binaries
  if [[ ! -d offline-packages/linux ]]; then
    echo "Error: Linux binaries not found. Did you download the macOS package by mistake?"
    exit 1
  fi

  echo ""
  echo "Installing core binaries..."
  install_binary "offline-packages/linux/wezterm.AppImage" "wezterm" "WezTerm" "--version"
  install_binary "offline-packages/linux/tmux-3.4-static-x86_64" "tmux" "tmux" "-V"
  install_binary "offline-packages/linux/fzf" "fzf" "fzf" "--version"
  install_binary "offline-packages/linux/fd" "fd" "fd" "--version"
  install_binary "offline-packages/linux/rg" "rg" "ripgrep" "--version"
  install_binary "offline-packages/linux/bat" "bat" "bat" "--version"
  install_binary "offline-packages/linux/starship" "starship" "starship" "--version"

  echo ""
  echo "Installing optional tools..."
  install_binary "offline-packages/linux/lsd" "lsd" "lsd" "--version"
  install_binary "offline-packages/linux/btop" "btop" "btop" "--version"
  install_binary "offline-packages/linux/eza" "eza" "eza" "--version"
  install_binary "offline-packages/linux/zoxide" "zoxide" "zoxide" "--version"
  install_binary "offline-packages/linux/delta" "delta" "delta" "--version"

  # Extract Neovim to /opt (or ~/ if no sudo)
  echo ""
  echo "Installing Neovim..."
  if [[ -f offline-packages/linux/nvim-linux64.tar.gz ]]; then
    # Check if nvim already exists
    if [[ -f "$BIN_DIR/nvim" ]]; then
      existing_ver=$(get_version "$BIN_DIR/nvim" "--version")
      # Extract to temp to check new version
      tar -xzf offline-packages/linux/nvim-linux64.tar.gz -C /tmp/
      new_ver=$(get_version "/tmp/nvim-linux-x86_64/bin/nvim" "--version")

      if prompt_overwrite "Neovim" "$existing_ver" "$new_ver" "$BIN_DIR/nvim"; then
        if [[ -n "$USE_SUDO" ]]; then
          $USE_SUDO rm -rf /opt/nvim-linux-x86_64
          $USE_SUDO mv /tmp/nvim-linux-x86_64 /opt/
          $USE_SUDO ln -sf /opt/nvim-linux-x86_64/bin/nvim "$BIN_DIR/nvim"
        else
          rm -rf ~/nvim-linux-x86_64
          mv /tmp/nvim-linux-x86_64 ~/
          ln -sf ~/nvim-linux-x86_64/bin/nvim "$BIN_DIR/nvim"
        fi
        echo "✓ Neovim updated"
      else
        rm -rf /tmp/nvim-linux-x86_64
        echo "⊘ Skipped Neovim"
      fi
    else
      # Fresh install
      tar -xzf offline-packages/linux/nvim-linux64.tar.gz -C /tmp/
      if [[ -n "$USE_SUDO" ]]; then
        $USE_SUDO mv /tmp/nvim-linux-x86_64 /opt/
        $USE_SUDO ln -sf /opt/nvim-linux-x86_64/bin/nvim "$BIN_DIR/nvim"
      else
        mv /tmp/nvim-linux-x86_64 ~/
        ln -sf ~/nvim-linux-x86_64/bin/nvim "$BIN_DIR/nvim"
      fi
      echo "✓ Neovim installed"
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

  echo ""
  echo "Installing macOS binaries..."

  # WezTerm
  if [[ -d /Applications/WezTerm.app ]]; then
    echo "WezTerm already installed at /Applications/WezTerm.app"
    read -p "Overwrite? [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      unzip -oq offline-packages/macos/WezTerm-macos.zip -d /Applications/
      echo "✓ WezTerm updated"
    else
      echo "⊘ Skipped WezTerm"
    fi
  else
    unzip -q offline-packages/macos/WezTerm-macos.zip -d /Applications/
    echo "✓ WezTerm installed"
  fi

  # Neovim
  echo ""
  echo "Installing Neovim..."
  if [[ -f "$BIN_DIR/nvim" ]]; then
    existing_ver=$(get_version "$BIN_DIR/nvim" "--version")
    tar -xzf offline-packages/macos/nvim-macos-arm64.tar.gz -C /tmp/
    new_ver=$(get_version "/tmp/nvim-macos-arm64/bin/nvim" "--version")

    if prompt_overwrite "Neovim" "$existing_ver" "$new_ver" "$BIN_DIR/nvim"; then
      $USE_SUDO cp /tmp/nvim-macos-arm64/bin/nvim "$BIN_DIR/"
      echo "✓ Neovim updated"
    else
      echo "⊘ Skipped Neovim"
    fi
    rm -rf /tmp/nvim-macos-arm64
  else
    tar -xzf offline-packages/macos/nvim-macos-arm64.tar.gz -C /tmp/
    $USE_SUDO cp /tmp/nvim-macos-arm64/bin/nvim "$BIN_DIR/"
    rm -rf /tmp/nvim-macos-arm64
    echo "✓ Neovim installed"
  fi
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