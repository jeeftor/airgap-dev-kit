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

    # Skip if same version
    if [[ "$existing_ver" == "$new_ver" ]]; then
      echo "✓ gum (already up-to-date: $existing_ver)"
    elif prompt_overwrite "gum" "$existing_ver" "$new_ver" "$BIN_DIR/gum"; then
      $USE_SUDO cp offline-packages/$OS/gum "$BIN_DIR/"
      $USE_SUDO chmod +x "$BIN_DIR/gum"
      echo "✓ gum updated ($existing_ver → $new_ver)"
    else
      echo "⊘ Skipped gum"
    fi
  else
    $USE_SUDO cp offline-packages/$OS/gum "$BIN_DIR/"
    $USE_SUDO chmod +x "$BIN_DIR/gum"
    echo "✓ gum installed"
  fi
fi

# Helper function to check if binary needs update
needs_update() {
  local source_file="$1"
  local dest_path="$2"
  local version_flag="$3"

  if [[ ! -f "$dest_path" ]]; then
    echo "new"  # New installation
    return
  fi

  local existing_ver=$(get_version "$dest_path" "$version_flag")
  local new_ver=$(get_version "$source_file" "$version_flag")

  if [[ "$existing_ver" == "$new_ver" ]]; then
    echo "same"  # Same version, skip
  else
    echo "update"  # Different version, needs update
  fi
}

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

    # Skip if same version
    if [[ "$existing_ver" == "$new_ver" ]]; then
      echo "✓ $tool_name (already up-to-date: $existing_ver)"
      return
    fi

    if prompt_overwrite "$tool_name" "$existing_ver" "$new_ver" "$dest_path"; then
      $USE_SUDO cp "$source_file" "$dest_path"
      $USE_SUDO chmod +x "$dest_path"
      echo "✓ $tool_name updated ($existing_ver → $new_ver)"
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

  # Ask about GUI/headless environment
  echo ""
  if has_gum && [[ -f "$BIN_DIR/gum" ]]; then
    if $BIN_DIR/gum confirm "Install WezTerm (GUI terminal emulator)?"; then
      INSTALL_WEZTERM=true
    else
      INSTALL_WEZTERM=false
    fi
  else
    read -p "Install WezTerm (GUI terminal emulator)? Needed for desktop, skip for SSH-only servers [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      INSTALL_WEZTERM=true
    else
      INSTALL_WEZTERM=false
    fi
  fi

  # Collect binaries that need updates
  declare -a BINARIES_TO_CHECK=()
  declare -a BINARY_SOURCES=()
  declare -a BINARY_DESTS=()
  declare -a BINARY_NAMES=()
  declare -a BINARY_FLAGS=()

  # Core binaries
  if [[ "$INSTALL_WEZTERM" == true ]]; then
    BINARIES_TO_CHECK+=("offline-packages/linux/wezterm.AppImage|wezterm|WezTerm|--version")
  fi
  BINARIES_TO_CHECK+=(
    "offline-packages/linux/tmux-3.4-static-x86_64|tmux|tmux|-V"
    "offline-packages/linux/fzf|fzf|fzf|--version"
    "offline-packages/linux/fd|fd|fd|--version"
    "offline-packages/linux/rg|rg|ripgrep|--version"
    "offline-packages/linux/bat|bat|bat|--version"
    "offline-packages/linux/starship|starship|starship|--version"
  )

  # Optional tools
  [[ -f "offline-packages/linux/lsd" ]] && BINARIES_TO_CHECK+=("offline-packages/linux/lsd|lsd|lsd|--version")
  [[ -f "offline-packages/linux/btop" ]] && BINARIES_TO_CHECK+=("offline-packages/linux/btop|btop|btop|--version")
  [[ -f "offline-packages/linux/eza" ]] && BINARIES_TO_CHECK+=("offline-packages/linux/eza|eza|eza|--version")
  [[ -f "offline-packages/linux/zoxide" ]] && BINARIES_TO_CHECK+=("offline-packages/linux/zoxide|zoxide|zoxide|--version")
  [[ -f "offline-packages/linux/delta" ]] && BINARIES_TO_CHECK+=("offline-packages/linux/delta|delta|delta|--version")

  # Scan for updates needed
  declare -a UPDATES_NEEDED=()
  declare -a NEW_INSTALLS=()
  declare -a UP_TO_DATE=()

  for binary_spec in "${BINARIES_TO_CHECK[@]}"; do
    IFS='|' read -r source dest name flag <<< "$binary_spec"
    [[ ! -f "$source" ]] && continue

    status=$(needs_update "$source" "$BIN_DIR/$dest" "$flag")
    case "$status" in
      new)
        NEW_INSTALLS+=("$binary_spec")
        ;;
      update)
        existing_ver=$(get_version "$BIN_DIR/$dest" "$flag")
        new_ver=$(get_version "$source" "$flag")
        UPDATES_NEEDED+=("$name ($existing_ver → $new_ver)|$binary_spec")
        ;;
      same)
        UP_TO_DATE+=("$name")
        ;;
    esac
  done

  # Show what's up to date
  if [[ ${#UP_TO_DATE[@]} -gt 0 ]]; then
    echo ""
    echo "Already up-to-date:"
    for tool in "${UP_TO_DATE[@]}"; do
      echo "  ✓ $tool"
    done
  fi

  # If there are updates or new installs, prompt with multi-select
  if [[ ${#UPDATES_NEEDED[@]} -gt 0 ]] || [[ ${#NEW_INSTALLS[@]} -gt 0 ]]; then
    echo ""

    # Build selection list
    declare -a INSTALL_CHOICES=()
    for item in "${NEW_INSTALLS[@]}"; do
      IFS='|' read -r source dest name flag <<< "$item"
      INSTALL_CHOICES+=("$name (new)|$item")
    done
    for item in "${UPDATES_NEEDED[@]}"; do
      INSTALL_CHOICES+=("$item")
    done

    # Use gum for multi-select if available
    declare -a SELECTED_BINARIES=()
    if has_gum && [[ -f "$BIN_DIR/gum" ]]; then
      echo "Select binaries to install/update:"
      echo ""

      # Create choices file
      for choice in "${INSTALL_CHOICES[@]}"; do
        IFS='|' read -r display spec <<< "$choice"
        echo "$display"
      done > /tmp/binary_choices.txt

      # Run gum choose with multi-select
      if selected=$($BIN_DIR/gum choose --no-limit < /tmp/binary_choices.txt); then
        while IFS= read -r line; do
          # Find the matching spec
          for choice in "${INSTALL_CHOICES[@]}"; do
            IFS='|' read -r display spec <<< "$choice"
            if [[ "$display" == "$line" ]]; then
              SELECTED_BINARIES+=("$spec")
              break
            fi
          done
        done <<< "$selected"
      else
        echo "No binaries selected."
      fi
      rm -f /tmp/binary_choices.txt
    else
      # Fallback: install all updates
      echo "The following binaries will be installed/updated:"
      for choice in "${INSTALL_CHOICES[@]}"; do
        IFS='|' read -r display spec <<< "$choice"
        echo "  • $display"
      done
      echo ""
      read -p "Continue? [Y/n]: " -n 1 -r
      echo
      if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
        for choice in "${INSTALL_CHOICES[@]}"; do
          IFS='|' read -r display spec <<< "$choice"
          SELECTED_BINARIES+=("$spec")
        done
      fi
    fi

    # Install selected binaries
    echo ""
    echo "Installing binaries..."
    for binary_spec in "${SELECTED_BINARIES[@]}"; do
      IFS='|' read -r source dest name flag <<< "$binary_spec"
      # Use simplified install (no prompting since already selected)
      if [[ -f "$source" ]]; then
        $USE_SUDO cp "$source" "$BIN_DIR/$dest"
        $USE_SUDO chmod +x "$BIN_DIR/$dest"
        echo "✓ $name installed"
      fi
    done
  else
    echo ""
    echo "✓ All binaries are already up-to-date!"
  fi

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

      # Skip if same version
      if [[ "$existing_ver" == "$new_ver" ]]; then
        echo "✓ Neovim (already up-to-date: $existing_ver)"
        rm -rf /tmp/nvim-linux-x86_64
      elif prompt_overwrite "Neovim" "$existing_ver" "$new_ver" "$BIN_DIR/nvim"; then
        if [[ -n "$USE_SUDO" ]]; then
          $USE_SUDO rm -rf /opt/nvim-linux-x86_64
          $USE_SUDO mv /tmp/nvim-linux-x86_64 /opt/
          $USE_SUDO ln -sf /opt/nvim-linux-x86_64/bin/nvim "$BIN_DIR/nvim"
        else
          rm -rf ~/nvim-linux-x86_64
          mv /tmp/nvim-linux-x86_64 ~/
          ln -sf ~/nvim-linux-x86_64/bin/nvim "$BIN_DIR/nvim"
        fi
        echo "✓ Neovim updated ($existing_ver → $new_ver)"
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

  # Install fzf shell integration scripts
  if [[ -d offline-packages/linux/fzf-scripts ]]; then
    echo ""
    echo "Installing fzf shell integration..."
    mkdir -p ~/.fzf/shell
    cp offline-packages/linux/fzf-scripts/* ~/.fzf/shell/
    echo "✓ fzf shell scripts installed to ~/.fzf/shell/"
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

    # Skip if same version
    if [[ "$existing_ver" == "$new_ver" ]]; then
      echo "✓ Neovim (already up-to-date: $existing_ver)"
      rm -rf /tmp/nvim-macos-arm64
    elif prompt_overwrite "Neovim" "$existing_ver" "$new_ver" "$BIN_DIR/nvim"; then
      $USE_SUDO cp /tmp/nvim-macos-arm64/bin/nvim "$BIN_DIR/"
      echo "✓ Neovim updated ($existing_ver → $new_ver)"
      rm -rf /tmp/nvim-macos-arm64
    else
      echo "⊘ Skipped Neovim"
      rm -rf /tmp/nvim-macos-arm64
    fi
  else
    tar -xzf offline-packages/macos/nvim-macos-arm64.tar.gz -C /tmp/
    $USE_SUDO cp /tmp/nvim-macos-arm64/bin/nvim "$BIN_DIR/"
    rm -rf /tmp/nvim-macos-arm64
    echo "✓ Neovim installed"
  fi

  # Install fzf shell integration scripts
  if [[ -d offline-packages/macos/fzf-scripts ]]; then
    echo ""
    echo "Installing fzf shell integration..."
    mkdir -p ~/.fzf/shell
    cp offline-packages/macos/fzf-scripts/* ~/.fzf/shell/
    echo "✓ fzf shell scripts installed to ~/.fzf/shell/"
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
  # Ensure .config is owned by the user, not root
  if [[ -d ~/.config ]] && [[ ! -w ~/.config ]]; then
    echo "  Fixing permissions on ~/.config..."
    $USE_SUDO chown -R $(whoami):$(id -gn) ~/.config
  fi

  # Copy config files directly (stow not available)
  if [[ -d config/.config ]]; then
    mkdir -p ~/.config
    cp -r config/.config/* ~/.config/ 2>/dev/null || {
      echo "  Permission issue detected, using sudo for config copy..."
      $USE_SUDO cp -r config/.config/* ~/.config/
      $USE_SUDO chown -R $(whoami):$(id -gn) ~/.config
    }
  fi
  # Copy other dotfiles if they exist (but skip . and ..)
  for file in config/.*; do
    # Skip . and .. directories
    [[ "$file" == "config/." ]] || [[ "$file" == "config/.." ]] && continue
    # Only process actual files
    if [[ -f "$file" ]]; then
      cp "$file" ~/ 2>/dev/null || $USE_SUDO cp "$file" ~/
    fi
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
if [[ "$INSTALL_WEZTERM" == true || "$OSTYPE" == "darwin"* ]]; then
  echo "   wezterm start -- tmux new-session nvim  # GUI environment"
else
  echo "   tmux new-session nvim  # Headless/SSH"
fi
echo ""
echo "📚 Installed tools:"
if [[ "$INSTALL_WEZTERM" == true || "$OSTYPE" == "darwin"* ]]; then
  echo "   Terminal: wezterm (GUI), tmux (multiplexer)"
else
  echo "   Terminal: tmux (multiplexer)"
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

# ==============================================================================
# Optional: Shell Configuration Setup
# ==============================================================================

echo ""
echo "=========================================="
echo "Shell Configuration"
echo "=========================================="
echo ""

# Helper function to check if a line exists in a file
config_exists() {
  local file="$1"
  local pattern="$2"
  [[ -f "$file" ]] && grep -qF "$pattern" "$file"
}

# Helper function to add configuration to shell RC file
add_to_shell_rc() {
  local rc_file="$1"
  local config_line="$2"
  local description="$3"

  if config_exists "$rc_file" "$config_line"; then
    echo "  ✓ $description (already configured)"
    return 0
  fi

  if has_gum && [[ -f "$BIN_DIR/gum" ]]; then
    if $BIN_DIR/gum confirm "Add $description to $(basename $rc_file)?"; then
      # Try to write, handle permission issues
      if ! echo "" >> "$rc_file" 2>/dev/null; then
        echo "  Permission denied, fixing ownership..."
        $USE_SUDO chown $(whoami):$(id -gn) "$rc_file"
      fi
      echo "" >> "$rc_file"
      echo "# Added by airgap-dev-kit installer" >> "$rc_file"
      echo "$config_line" >> "$rc_file"
      echo "  ✓ Added $description"
      return 0
    else
      echo "  ⊘ Skipped $description"
      return 1
    fi
  else
    read -p "Add $description to $(basename $rc_file)? [Y/n]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
      # Try to write, handle permission issues
      if ! echo "" >> "$rc_file" 2>/dev/null; then
        echo "  Permission denied, fixing ownership..."
        $USE_SUDO chown $(whoami):$(id -gn) "$rc_file"
      fi
      echo "" >> "$rc_file"
      echo "# Added by airgap-dev-kit installer" >> "$rc_file"
      echo "$config_line" >> "$rc_file"
      echo "  ✓ Added $description"
      return 0
    else
      echo "  ⊘ Skipped $description"
      return 1
    fi
  fi
}

# Detect user's shell
DETECTED_SHELLS=()
[[ -f "$HOME/.bashrc" ]] && DETECTED_SHELLS+=("$HOME/.bashrc")
[[ -f "$HOME/.zshrc" ]] && DETECTED_SHELLS+=("$HOME/.zshrc")
[[ -f "$HOME/.config/fish/config.fish" ]] && DETECTED_SHELLS+=("$HOME/.config/fish/config.fish")

if [[ ${#DETECTED_SHELLS[@]} -eq 0 ]]; then
  echo "No shell configuration files found (.bashrc, .zshrc, config.fish)"
  echo "You can manually add configurations later using shell-setup-example.sh as reference"
else
  echo "Detected shell configuration files:"
  for shell_rc in "${DETECTED_SHELLS[@]}"; do
    echo "  • $(basename $shell_rc)"
  done
  echo ""

  if has_gum && [[ -f "$BIN_DIR/gum" ]]; then
    if ! $BIN_DIR/gum confirm "Configure shells automatically?"; then
      echo ""
      echo "Skipped automatic shell configuration."
      echo "See shell-setup-example.sh for manual setup instructions."
      exit 0
    fi
  else
    read -p "Configure shells automatically? [Y/n]: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]] && [[ -n $REPLY ]]; then
      echo ""
      echo "Skipped automatic shell configuration."
      echo "See shell-setup-example.sh for manual setup instructions."
      exit 0
    fi
  fi

  echo ""

  for SHELL_RC in "${DETECTED_SHELLS[@]}"; do
    echo "Configuring $(basename $SHELL_RC)..."
    echo ""

    # Determine shell type
    SHELL_TYPE="bash"
    if [[ "$SHELL_RC" == *"zshrc"* ]]; then
      SHELL_TYPE="zsh"
    elif [[ "$SHELL_RC" == *"fish"* ]]; then
      SHELL_TYPE="fish"
    fi

    # PATH configuration (only if needed)
    if [[ "$BIN_DIR" == "$HOME/bin" ]]; then
      if [[ "$SHELL_TYPE" == "fish" ]]; then
        add_to_shell_rc "$SHELL_RC" "set -gx PATH \$HOME/bin \$PATH" "PATH configuration"
      else
        add_to_shell_rc "$SHELL_RC" "export PATH=\"\$HOME/bin:\$PATH\"" "PATH configuration"
      fi
    fi

    # Starship prompt
    if command -v starship &>/dev/null || [[ -f "$BIN_DIR/starship" ]]; then
      if [[ "$SHELL_TYPE" == "fish" ]]; then
        add_to_shell_rc "$SHELL_RC" "starship init fish | source" "Starship prompt"
      else
        add_to_shell_rc "$SHELL_RC" "eval \"\$(starship init $SHELL_TYPE)\"" "Starship prompt"
      fi
    fi

    # Zoxide (smarter cd)
    if [[ -f "$BIN_DIR/zoxide" ]]; then
      if [[ "$SHELL_TYPE" == "fish" ]]; then
        add_to_shell_rc "$SHELL_RC" "zoxide init fish | source" "Zoxide (z command)"
      else
        add_to_shell_rc "$SHELL_RC" "eval \"\$(zoxide init $SHELL_TYPE)\"" "Zoxide (z command)"
      fi
    fi

    # fzf shell integration (Ctrl+R history, Ctrl+T file finder, Alt+C cd)
    if [[ -d ~/.fzf/shell ]]; then
      # Set FZF defaults (without --height to avoid conflicts with key-bindings)
      if [[ "$SHELL_TYPE" == "bash" ]] || [[ "$SHELL_TYPE" == "zsh" ]]; then
        add_to_shell_rc "$SHELL_RC" "export FZF_DEFAULT_OPTS='--border --prompt=\"> \" --pointer=\"▶\" --marker=\"✓\"'" "fzf default options"
        # Optional: Use fd for fzf if available
        if [[ -f "$BIN_DIR/fd" ]]; then
          add_to_shell_rc "$SHELL_RC" "export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'" "fzf use fd for file search"
          add_to_shell_rc "$SHELL_RC" "export FZF_CTRL_T_COMMAND=\"\$FZF_DEFAULT_COMMAND\"" "fzf Ctrl+T uses fd"
        fi
      fi

      if [[ "$SHELL_TYPE" == "bash" ]]; then
        add_to_shell_rc "$SHELL_RC" "source ~/.fzf/shell/key-bindings.bash" "fzf key bindings (Ctrl+R, Ctrl+T)"
        add_to_shell_rc "$SHELL_RC" "source ~/.fzf/shell/completion.bash" "fzf completions"
      elif [[ "$SHELL_TYPE" == "zsh" ]]; then
        add_to_shell_rc "$SHELL_RC" "source ~/.fzf/shell/key-bindings.zsh" "fzf key bindings (Ctrl+R, Ctrl+T)"
        add_to_shell_rc "$SHELL_RC" "source ~/.fzf/shell/completion.zsh" "fzf completions"
      elif [[ "$SHELL_TYPE" == "fish" ]]; then
        add_to_shell_rc "$SHELL_RC" "source ~/.fzf/shell/key-bindings.fish" "fzf key bindings"
      fi
    fi

    # Aliases
    if [[ "$SHELL_TYPE" != "fish" ]]; then
      # lsd or eza
      if [[ -f "$BIN_DIR/lsd" ]]; then
        add_to_shell_rc "$SHELL_RC" "alias ls='lsd'" "lsd alias (modern ls)"
        add_to_shell_rc "$SHELL_RC" "alias ll='lsd -la'" "ll alias"
        add_to_shell_rc "$SHELL_RC" "alias tree='lsd --tree'" "tree alias"
      elif [[ -f "$BIN_DIR/eza" ]]; then
        add_to_shell_rc "$SHELL_RC" "alias ls='eza --icons'" "eza alias (modern ls)"
        add_to_shell_rc "$SHELL_RC" "alias ll='eza -la --icons'" "ll alias"
        add_to_shell_rc "$SHELL_RC" "alias tree='eza --tree --icons'" "tree alias"
      fi

      # bat
      if [[ -f "$BIN_DIR/bat" ]]; then
        add_to_shell_rc "$SHELL_RC" "alias cat='bat --paging=never'" "bat alias (syntax highlighting)"
      fi

      # fd
      if [[ -f "$BIN_DIR/fd" ]]; then
        add_to_shell_rc "$SHELL_RC" "alias find='fd'" "fd alias (faster find)"
      fi

      # ripgrep
      if [[ -f "$BIN_DIR/rg" ]]; then
        add_to_shell_rc "$SHELL_RC" "alias grep='rg'" "ripgrep alias (faster grep)"
      fi

      # neovim
      if [[ -f "$BIN_DIR/nvim" ]]; then
        add_to_shell_rc "$SHELL_RC" "alias vim='nvim'" "nvim alias"
        add_to_shell_rc "$SHELL_RC" "alias vi='nvim'" "vi alias"
        add_to_shell_rc "$SHELL_RC" "export EDITOR='nvim'" "EDITOR environment variable"
      fi

      # tmux helper alias
      if [[ -f "$BIN_DIR/tmux" ]]; then
        add_to_shell_rc "$SHELL_RC" "alias ta='tmux attach -t'" "tmux attach alias"
        add_to_shell_rc "$SHELL_RC" "alias tl='tmux list-sessions'" "tmux list alias"
        add_to_shell_rc "$SHELL_RC" "alias tn='tmux new -s'" "tmux new session alias"
      fi
    fi

    echo ""
  done

  echo "=========================================="
  echo "✓ Shell configuration complete!"
  echo "=========================================="
  echo ""
  echo "To apply changes, either:"
  echo "  • Restart your terminal, or"
  echo "  • Run: source ~/.bashrc  (or ~/.zshrc)"
fi

echo ""