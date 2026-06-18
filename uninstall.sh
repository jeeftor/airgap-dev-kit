#!/usr/bin/env bash
# Air-Gap Dev Kit - Uninstaller
# Removes all installed binaries and configurations

set -e

# Installation log file
INSTALL_LOG="$HOME/.airgap-dev-kit-install.log"

echo "=========================================="
echo "Air-Gap Dev Kit - Uninstaller"
echo "=========================================="
echo ""

# Helper function to check if gum is available
has_gum() {
  command -v gum &>/dev/null
}

# Check if we have an installation log
if [[ -f "$INSTALL_LOG" ]]; then
  echo "✓ Found installation log: $INSTALL_LOG"
  echo "  Using tracked installation data for precise uninstallation"
  USE_LOG=true
else
  echo "⚠ No installation log found at: $INSTALL_LOG"
  echo "  Will use fallback method (may not remove everything)"
  USE_LOG=false
fi
echo ""

# Detect OS
if [[ "$OSTYPE" == "darwin"* ]]; then
  OS="macos"
else
  OS="linux"
fi

echo "Detected OS: $OS"
echo ""

# Parse installation log if available
parse_install_log() {
  if [[ ! -f "$INSTALL_LOG" ]]; then
    return 1
  fi
  
  # Extract metadata
  BIN_DIR=$(grep "^METADATA|BIN_DIR=" "$INSTALL_LOG" | head -1 | cut -d'=' -f2)
  USE_SUDO_ORIG=$(grep "^METADATA|USE_SUDO=" "$INSTALL_LOG" | head -1 | cut -d'=' -f2)
  
  echo "Installation details from log:"
  echo "  Binary directory: $BIN_DIR"
  echo "  Used sudo: $USE_SUDO_ORIG"
  echo ""
  
  # Count items
  BINARY_COUNT=$(grep "^BINARY|" "$INSTALL_LOG" | wc -l | tr -d ' ')
  CONFIG_COUNT=$(grep "^CONFIG|" "$INSTALL_LOG" | wc -l | tr -d ' ')
  STOW_COUNT=$(grep "^STOW_PACKAGE|" "$INSTALL_LOG" | wc -l | tr -d ' ')
  SHELL_COUNT=$(grep "^SHELL_CONFIG|" "$INSTALL_LOG" | wc -l | tr -d ' ')
  
  echo "Items to remove:"
  echo "  Binaries: $BINARY_COUNT"
  echo "  Config files: $CONFIG_COUNT"
  echo "  Stow packages: $STOW_COUNT"
  echo "  Shell configurations: $SHELL_COUNT"
  echo ""
}

if [[ "$USE_LOG" == true ]]; then
  parse_install_log
fi

# Check for installation directories
INSTALL_LOCATIONS=()
if [[ -f "/usr/local/bin/nvim" ]] || [[ -f "/usr/local/bin/fzf" ]]; then
  INSTALL_LOCATIONS+=("/usr/local/bin")
fi
if [[ -f "$HOME/.local/bin/nvim" ]] || [[ -f "$HOME/.local/bin/fzf" ]] || [[ -f "$HOME/.local/bin/starship" ]]; then
  INSTALL_LOCATIONS+=("$HOME/.local/bin")
fi
if [[ -f "$HOME/bin/nvim" ]] || [[ -f "$HOME/bin/fzf" ]]; then
  INSTALL_LOCATIONS+=("$HOME/bin")
fi

# If still empty but we have a log with BIN_DIR, use that
if [[ ${#INSTALL_LOCATIONS[@]} -eq 0 ]] && [[ "$USE_LOG" == true ]]; then
  LOG_BIN_DIR=$(grep "^METADATA|BIN_DIR=" "$INSTALL_LOG" 2>/dev/null | head -1 | cut -d'=' -f2)
  if [[ -n "$LOG_BIN_DIR" && -d "$LOG_BIN_DIR" ]]; then
    INSTALL_LOCATIONS+=("$LOG_BIN_DIR")
    echo "  Using BIN_DIR from installation log: $LOG_BIN_DIR"
  fi
fi

if [[ ${#INSTALL_LOCATIONS[@]} -eq 0 ]]; then
  echo "No Air-Gap Dev Kit installation found."
  echo "Nothing to uninstall."
  exit 0
fi

echo "Found installations in:"
for location in "${INSTALL_LOCATIONS[@]}"; do
  echo "  • $location"
done
echo ""

# Warning prompt
if has_gum; then
  gum style --border double --border-foreground 196 --padding "1 2" --margin "1 0" \
    "⚠️  WARNING" \
    "" \
    "This will remove all Air-Gap Dev Kit binaries and configurations." \
    "" \
    "The following will be removed:" \
    "  • Binaries: wezterm, tmux, nvim, fzf, fd, rg, bat, starship, etc." \
    "  • Configs: ~/.config/nvim/, ~/.tmux.conf, ~/.config/starship.toml" \
    "  • Fonts: JetBrainsMono Nerd Font" \
    "  • Shell configurations (aliases and initializations)"

  echo ""
  if ! gum confirm "Continue with uninstallation?"; then
    echo "Uninstall cancelled."
    exit 0
  fi
else
  echo "⚠️  WARNING: This will remove all Air-Gap Dev Kit binaries and configurations."
  echo ""
  echo "The following will be removed:"
  echo "  • Binaries: wezterm, tmux, nvim, fzf, fd, rg, bat, starship, etc."
  echo "  • Configs: ~/.config/nvim/, ~/.tmux.conf, ~/.config/starship.toml"
  echo "  • Fonts: JetBrainsMono Nerd Font"
  echo "  • Shell configurations (aliases and initializations)"
  echo ""
  read -p "Continue with uninstallation? [y/N]: " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Uninstall cancelled."
    exit 0
  fi
fi

echo ""
echo "=========================================="
echo "Uninstalling..."
echo "=========================================="
echo ""

# Determine if we need sudo
USE_SUDO=""
if [[ " ${INSTALL_LOCATIONS[@]} " =~ " /usr/local/bin " ]]; then
  if [[ $EUID -ne 0 ]]; then
    echo "System-wide installation detected. Requesting sudo privileges..."
    if sudo -v; then
      USE_SUDO="sudo"
      # Keep sudo alive
      while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
    else
      echo "Error: Sudo authentication failed. Cannot remove system-wide binaries."
      exit 1
    fi
  fi
fi

# List of binaries to remove
BINARIES=(
  "wezterm"
  "tmux"
  "nvim"
  "fzf"
  "fd"
  "rg"
  "bat"
  "starship"
  "lsd"
  "btop"
  "eza"
  "zoxide"
  "delta"
  "gum"
)

# Remove binaries (using log if available)
echo "Removing binaries..."
if [[ "$USE_LOG" == true ]]; then
  # Use log for precise removal
  while IFS='|' read -r type path backup timestamp; do
    if [[ "$type" == "BINARY" && -f "$path" ]]; then
      if [[ "$path" == /usr/local/bin/* ]]; then
        $USE_SUDO rm -f "$path"
      else
        rm -f "$path"
      fi
      echo "  ✓ Removed $(basename $path) from $(dirname $path)"
      
      # Restore backup if requested
      if [[ -n "$backup" && -f "$backup" ]]; then
        echo "    (Backup available: $backup)"
      fi
    fi
  done < <(grep "^BINARY|" "$INSTALL_LOG")
else
  # Fallback: use hardcoded list
  for location in "${INSTALL_LOCATIONS[@]}"; do
    for binary in "${BINARIES[@]}"; do
      if [[ -f "$location/$binary" ]]; then
        if [[ "$location" == "/usr/local/bin" ]]; then
          $USE_SUDO rm -f "$location/$binary"
        else
          rm -f "$location/$binary"
        fi
        echo "  ✓ Removed $binary from $location"
      fi
    done
  done
fi

# Remove Neovim installation directories
if [[ $OS == "linux" ]]; then
  if [[ -d "/opt/nvim-linux-x86_64" ]]; then
    $USE_SUDO rm -rf /opt/nvim-linux-x86_64
    echo "  ✓ Removed /opt/nvim-linux-x86_64"
  fi
  if [[ -d "$HOME/nvim-linux-x86_64" ]]; then
    rm -rf "$HOME/nvim-linux-x86_64"
    echo "  ✓ Removed ~/nvim-linux-x86_64"
  fi
  # Remove bundled runtime (installed by official tarball approach)
  if [[ -d "$HOME/.local/share/nvim/runtime" ]]; then
    rm -rf "$HOME/.local/share/nvim/runtime"
    echo "  ✓ Removed ~/.local/share/nvim/runtime"
  fi
fi

# Remove WezTerm on macOS
if [[ $OS == "macos" ]] && [[ -d "/Applications/WezTerm.app" ]]; then
  if has_gum; then
    if gum confirm "Remove WezTerm.app from /Applications/?"; then
      rm -rf /Applications/WezTerm.app
      echo "  ✓ Removed WezTerm.app"
    fi
  else
    read -p "Remove WezTerm.app from /Applications/? [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      rm -rf /Applications/WezTerm.app
      echo "  ✓ Removed WezTerm.app"
    fi
  fi
fi

echo ""
echo "Removing configurations..."

# Unstow packages if using Stow
if [[ "$USE_LOG" == true ]] && command -v stow &>/dev/null; then
  STOW_PACKAGES=$(grep "^STOW_PACKAGE|" "$INSTALL_LOG" | cut -d'|' -f2)
  if [[ -n "$STOW_PACKAGES" ]]; then
    echo "  Unstowing packages..."
    for package in $STOW_PACKAGES; do
      if [[ -d "config/$package" ]]; then
        cd config && stow -D -t ~ "$package" && cd ..
        echo "    ✓ Unstowed $package"
      fi
    done
  fi
fi

# Remove configs (using log if available)
if [[ "$USE_LOG" == true ]]; then
  while IFS='|' read -r type path backup timestamp; do
    if [[ "$type" == "CONFIG" ]]; then
      if [[ -e "$path" ]]; then
        if has_gum; then
          if gum confirm "Remove config: $path?"; then
            rm -rf "$path"
            echo "  ✓ Removed $path"
            if [[ -n "$backup" && -e "$backup" ]]; then
              echo "    (Backup available: $backup)"
            fi
          fi
        else
          read -p "Remove config: $path? [y/N]: " -n 1 -r
          echo
          if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$path"
            echo "  ✓ Removed $path"
            if [[ -n "$backup" && -e "$backup" ]]; then
              echo "    (Backup available: $backup)"
            fi
          fi
        fi
      fi
    fi
  done < <(grep "^CONFIG|" "$INSTALL_LOG")
fi

# Fallback: Remove common configs
if [[ -d "$HOME/.config/nvim" ]]; then
  if has_gum; then
    if gum confirm "Remove Neovim config (~/.config/nvim/)?"; then
      rm -rf "$HOME/.config/nvim"
      echo "  ✓ Removed ~/.config/nvim/"
    fi
  else
    read -p "Remove Neovim config (~/.config/nvim/)? [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      rm -rf "$HOME/.config/nvim"
      echo "  ✓ Removed ~/.config/nvim/"
    fi
  fi
fi

if [[ -f "$HOME/.tmux.conf" ]]; then
  rm -f "$HOME/.tmux.conf"
  echo "  ✓ Removed ~/.tmux.conf"
fi

if [[ -f "$HOME/.config/starship.toml" ]]; then
  rm -f "$HOME/.config/starship.toml"
  echo "  ✓ Removed ~/.config/starship.toml"
fi

# Remove Neovim plugins and data
if [[ -d "$HOME/.local/share/nvim" ]]; then
  if has_gum; then
    if gum confirm "Remove Neovim plugins and data (~/.local/share/nvim/)?"; then
      rm -rf "$HOME/.local/share/nvim"
      echo "  ✓ Removed ~/.local/share/nvim/"
    fi
  else
    read -p "Remove Neovim plugins and data (~/.local/share/nvim/)? [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      rm -rf "$HOME/.local/share/nvim"
      echo "  ✓ Removed ~/.local/share/nvim/"
    fi
  fi
fi

# Remove fonts
echo ""
if has_gum; then
  if gum confirm "Remove JetBrainsMono Nerd Font?"; then
    REMOVE_FONTS=true
  else
    REMOVE_FONTS=false
  fi
else
  read -p "Remove JetBrainsMono Nerd Font? [y/N]: " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    REMOVE_FONTS=true
  else
    REMOVE_FONTS=false
  fi
fi

if [[ "$REMOVE_FONTS" == true ]]; then
  if [[ $OS == "linux" ]]; then
    rm -f "$HOME/.local/share/fonts/JetBrainsMono"*
    fc-cache -fv > /dev/null 2>&1
    echo "  ✓ Removed JetBrainsMono fonts"
  else
    echo "  ℹ macOS fonts must be removed manually via Font Book"
  fi
fi

# Clean shell configurations
echo ""
echo "Cleaning shell configurations..."
echo ""

SHELL_FILES=(
  "$HOME/.bashrc"
  "$HOME/.zshrc"
  "$HOME/.config/fish/config.fish"
)

for shell_file in "${SHELL_FILES[@]}"; do
  if [[ -f "$shell_file" ]]; then
    # Create backup
    cp "$shell_file" "${shell_file}.airgap-backup"

    # Remove lines added by installer
    if grep -q "# Added by airgap-dev-kit installer" "$shell_file"; then
      # Remove the comment line and the next line (the actual config)
      sed -i.tmp '/# Added by airgap-dev-kit installer/{N;d;}' "$shell_file"
      rm -f "${shell_file}.tmp"
      echo "  ✓ Cleaned $(basename $shell_file) (backup: ${shell_file}.airgap-backup)"
    fi
  fi
done

echo ""
echo "=========================================="
echo "✓ Uninstallation complete!"
echo "=========================================="
echo ""
echo "The following were preserved:"
echo "  • Shell config backups: ~/.bashrc.airgap-backup, ~/.zshrc.airgap-backup"
if [[ "$USE_LOG" == true ]]; then
  # Check for backups in log
  BACKUP_COUNT=$(grep -c "||" "$INSTALL_LOG" | grep -v "^0$" || echo "0")
  if [[ "$BACKUP_COUNT" -gt 0 ]]; then
    echo "  • File backups (see installation log for details)"
  fi
fi
echo "  • Any custom configurations you added manually"
echo ""
echo "To restore shell configs, run:"
echo "  mv ~/.bashrc.airgap-backup ~/.bashrc"
echo "  mv ~/.zshrc.airgap-backup ~/.zshrc"
echo ""

# Offer to remove installation log
if [[ "$USE_LOG" == true ]]; then
  echo "Installation log: $INSTALL_LOG"
  if has_gum; then
    if gum confirm "Remove installation log?"; then
      rm -f "$INSTALL_LOG"
      echo "✓ Installation log removed"
    else
      echo "Installation log preserved for reference"
    fi
  else
    read -p "Remove installation log? [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      rm -f "$INSTALL_LOG"
      echo "✓ Installation log removed"
    else
      echo "Installation log preserved for reference"
    fi
  fi
  echo ""
fi
