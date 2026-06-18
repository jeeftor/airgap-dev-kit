#!/usr/bin/env bash
set -e

# Color definitions
if [[ -t 1 ]]; then
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  MAGENTA='\033[0;35m'
  CYAN='\033[0;36m'
  BOLD='\033[1m'
  DIM='\033[2m'
  RESET='\033[0m'
  CHECK="${GREEN}✓${RESET}"
  ARROW="${CYAN}➜${RESET}"
  STAR="${YELLOW}★${RESET}"
else
  GREEN=''
  YELLOW=''
  BLUE=''
  MAGENTA=''
  CYAN=''
  BOLD=''
  DIM=''
  RESET=''
  CHECK='✓'
  ARROW='➜'
  STAR='★'
fi

# Parse command line arguments
DRY_RUN=false
CLI_ONLY=false
for arg in "$@"; do
  case $arg in
    --dry-run|-n)
      DRY_RUN=true
      shift
      ;;
    --cli-only)
      CLI_ONLY=true
      shift
      ;;
    --help|-h)
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --dry-run, -n    Show what would be installed without actually installing"
      echo "  --cli-only       Install CLI tools only; skip GUI tools, fonts, and prompts"
      echo "  --help, -h       Show this help message"
      exit 0
      ;;
  esac
done

# Determine kit version (from VERSION file if bundled, otherwise git)
KIT_VERSION="unknown"
if [[ -f VERSION ]]; then
  KIT_VERSION=$(head -n 1 VERSION | tr -d ' \t\r\n')
elif command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
  KIT_VERSION=$(git describe --tags --always --dirty 2>/dev/null || echo "unknown")
fi

if [[ -f .airgap-cli-only ]]; then
  CLI_ONLY=true
fi

# Installation tracking file
INSTALL_LOG="$HOME/.airgap-dev-kit-install.log"

# Initialize installation log
init_install_log() {
  cat > "$INSTALL_LOG" << EOF
# Air-Gap Dev Kit Installation Log
# Generated: $(date)
# This file tracks what was installed and can be used for uninstallation
#
# Format: TYPE|PATH|BACKUP_PATH|TIMESTAMP
# Types: BINARY, CONFIG, SYMLINK, DIRECTORY, SHELL_CONFIG
EOF
  echo "# Installation started at $(date)" >> "$INSTALL_LOG"
}

# Log an installed item
log_install() {
  if [[ "$DRY_RUN" == true ]]; then
    return 0
  fi
  local type="$1"
  local path="$2"
  local backup="${3:-}"
  local timestamp
  timestamp=$(date +%Y%m%d-%H%M%S)
  echo "$type|$path|$backup|$timestamp" >> "$INSTALL_LOG"
}

# Replace executables atomically so Linux can update a binary that is still
# running. Directly copying over an active executable can fail with ETXTBSY.
install_executable() {
  local source_file="$1"
  local dest_path="$2"
  local tmp_path="${dest_path}.tmp.$$"

  $USE_SUDO rm -f "$tmp_path"
  $USE_SUDO cp "$source_file" "$tmp_path"
  $USE_SUDO chmod +x "$tmp_path"
  $USE_SUDO mv -f "$tmp_path" "$dest_path"
}

# Helper function to check if gum is available (for pretty TUI prompts)
has_gum() {
  command -v gum &>/dev/null || [ -f "$PWD/offline-packages/linux/gum" ]
}

is_interactive() {
  [[ -t 0 && -t 1 ]]
}

can_use_gum_prompts() {
  [[ "$CLI_ONLY" == true ]] && return 1
  has_gum && is_interactive
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
  local version
  version=$("$binary" "$version_flag" 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1 || echo "unknown")
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

  if can_use_gum_prompts; then
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
    if ! is_interactive; then
      echo "Found existing $tool_name at $install_path; replacing non-interactively."
      return 0
    fi
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
  echo "Error: macOS is not supported by this kit. This repository targets Linux installs."
  exit 1
else
  OS="linux"
fi

echo ""
echo "=========================================="
echo "Air-Gap Dev Kit Installer"
echo "Version: ${KIT_VERSION}"
if [[ "$DRY_RUN" == true ]]; then
  echo "(DRY RUN MODE - No changes will be made)"
fi
if [[ "$CLI_ONLY" == true ]]; then
  echo "(CLI-only mode - GUI tools, fonts, and interactive prompts disabled)"
fi
echo "=========================================="
echo ""

# Initialize installation tracking
if [[ "$DRY_RUN" == false ]]; then
  init_install_log
  echo "Installation tracking: $INSTALL_LOG"
else
  echo "DRY RUN: Would create installation log at: $INSTALL_LOG"
fi
echo ""

# Determine install location - prompt user FIRST
# Check if we're already root
if [[ "$CLI_ONLY" == true && $EUID -ne 0 ]]; then
  echo "CLI-only mode: defaulting to user-local install."
  INSTALL_CHOICE="2"
elif [[ $EUID -eq 0 ]]; then
  echo "Note: Running as root, defaulting to system-wide install"
  INSTALL_CHOICE="1"
elif can_use_gum_prompts && command -v gum &> /dev/null; then
  # Use gum for a nice interactive prompt
  INSTALL_CHOICE=$(gum choose --header "Choose installation location:" \
    "System-wide (/usr/local/bin) - Available to all users, requires sudo" \
    "User-local (~/.local/bin) - No sudo needed, current user only")
  
  # Extract the choice type
  if [[ "$INSTALL_CHOICE" == System-wide* ]]; then
    INSTALL_CHOICE="1"
  else
    INSTALL_CHOICE="2"
  fi
else
  if ! is_interactive; then
    INSTALL_CHOICE="2"
  else
  # Fallback to basic prompt if gum not available
  echo "Choose installation location:"
  echo ""
  echo "1. System-wide (/usr/local/bin) - Recommended if you have sudo access"
  echo "   • Available to all users"
  echo "   • Requires root/sudo privileges"
  echo ""
  echo "2. User-local (~/.local/bin or ~/bin) - Best for restricted environments"
  echo "   • No root access needed"
  echo "   • Only available to current user"
  echo "   • Requires adding to PATH manually"
  echo ""
  
  if sudo -n true 2>/dev/null; then
    echo "Note: Passwordless sudo detected"
  fi
  
  read -p "Install location [1=system-wide, 2=user-local]: " -n 1 -r INSTALL_CHOICE
  echo
  fi
fi

# Default to user-local if no choice made
if [[ -z "$INSTALL_CHOICE" ]]; then
  INSTALL_CHOICE="2"
fi

echo ""

# Set up installation paths based on choice
if [[ "$INSTALL_CHOICE" == "1" ]]; then
  # System-wide installation
  if [[ $EUID -eq 0 ]]; then
    # Already running as root
    BIN_DIR="/usr/local/bin"
    USE_SUDO=""
    echo "✓ Installing to: $BIN_DIR (system-wide, as root)"
  elif sudo -v; then
    # Prompt for sudo and verify
    BIN_DIR="/usr/local/bin"
    USE_SUDO="sudo"
    echo "✓ Installing to: $BIN_DIR (system-wide, with sudo)"
    # Keep sudo alive in background
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
  else
    echo "✗ Sudo authentication failed. Falling back to user-local install."
    BIN_DIR="$HOME/.local/bin"
    USE_SUDO=""
    echo "✓ Installing to: $BIN_DIR (user-local)"
  fi
else
  # User-local installation
  BIN_DIR="$HOME/.local/bin"
  USE_SUDO=""
  echo "✓ Installing to: $BIN_DIR (user-local)"
fi

echo ""
echo "Installing $OS binaries..."

# Log installation metadata
log_install "METADATA" "OS=$OS" "" ""
log_install "METADATA" "KIT_DIR=$PWD" "" ""
log_install "METADATA" "BIN_DIR=$BIN_DIR" "" ""
log_install "METADATA" "USE_SUDO=$USE_SUDO" "" ""
log_install "METADATA" "KIT_VERSION=$KIT_VERSION" "" ""
log_install "DIRECTORY" "$BIN_DIR" "" ""

echo ""

if [[ "$DRY_RUN" == true ]]; then
  echo "DRY RUN: Would create directory: $BIN_DIR"
  if [[ "$CLI_ONLY" == true ]]; then
    echo "DRY RUN: Would install bundled CLI tools from offline-packages/linux."
    echo "DRY RUN: Would skip WezTerm, GUI fonts, and automatic shell configuration."
    echo ""
    echo "CLI-only dry run complete."
    exit 0
  fi
else
  $USE_SUDO mkdir -p "$BIN_DIR"
fi

# Install gum first (so we can use it for prompts)
if [[ -f offline-packages/$OS/gum ]]; then
  if [[ -f "$BIN_DIR/gum" ]]; then
    existing_ver=$(get_version "$BIN_DIR/gum")
    new_ver=$(get_version "offline-packages/$OS/gum")

    # Skip if same version
    if [[ "$existing_ver" == "$new_ver" ]]; then
      echo "✓ gum (already up-to-date: $existing_ver)"
    elif prompt_overwrite "gum" "$existing_ver" "$new_ver" "$BIN_DIR/gum"; then
      install_executable "offline-packages/$OS/gum" "$BIN_DIR/gum"
      echo "✓ gum updated ($existing_ver → $new_ver)"
    else
      echo "⊘ Skipped gum"
    fi
  else
    install_executable "offline-packages/$OS/gum" "$BIN_DIR/gum"
    echo "✓ gum installed"
    log_install "BINARY" "$BIN_DIR/gum" "" ""
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

  local existing_ver
  local new_ver
  existing_ver=$(get_version "$dest_path" "$version_flag")
  new_ver=$(get_version "$source_file" "$version_flag")

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
  local backup_path=""

  if [[ -f "$dest_path" ]]; then
    # Binary exists, check version
    local existing_ver
    local new_ver
    existing_ver=$(get_version "$dest_path" "$version_flag")
    new_ver=$(get_version "$source_file" "$version_flag")

    # Skip if same version
    if [[ "$existing_ver" == "$new_ver" ]]; then
      echo "✓ $tool_name (already up-to-date: $existing_ver)"
      log_install "BINARY" "$dest_path" "" ""
      return
    fi

    if prompt_overwrite "$tool_name" "$existing_ver" "$new_ver" "$dest_path"; then
      # Create backup before overwriting
      backup_path="${dest_path}.backup-$(date +%Y%m%d-%H%M%S)"
      $USE_SUDO cp "$dest_path" "$backup_path"
      
      install_executable "$source_file" "$dest_path"
      echo "✓ $tool_name updated ($existing_ver → $new_ver)"
      log_install "BINARY" "$dest_path" "$backup_path" ""
    else
      echo "⊘ Skipped $tool_name"
    fi
  else
    # Fresh install
    if [[ "$DRY_RUN" == true ]]; then
      echo "DRY RUN: Would install $tool_name to $dest_path"
    else
      install_executable "$source_file" "$dest_path"
      echo "✓ $tool_name installed"
      log_install "BINARY" "$dest_path" "" ""
    fi
  fi
}

if [[ $OS == "linux" ]]; then
  # Check if we have linux binaries
  if [[ ! -d offline-packages/linux ]]; then
    echo "Error: Linux binaries not found. Run 'make update' on an online machine first."
    exit 1
  fi

  # Ask about GUI/headless environment
  echo ""
  if [[ "$CLI_ONLY" == true ]]; then
    echo "CLI-only mode: skipping WezTerm."
    INSTALL_WEZTERM=false
  elif can_use_gum_prompts && [[ -f "$BIN_DIR/gum" ]]; then
    if "$BIN_DIR"/gum confirm "Install WezTerm (GUI terminal emulator)?"; then
      INSTALL_WEZTERM=true
    else
      INSTALL_WEZTERM=false
    fi
  else
    if ! is_interactive; then
      echo "Skipping WezTerm in non-interactive install."
      INSTALL_WEZTERM=false
    else
    read -p "Install WezTerm (GUI terminal emulator)? Needed for desktop, skip for SSH-only servers [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      INSTALL_WEZTERM=true
    else
      INSTALL_WEZTERM=false
    fi
    fi
  fi

  # Collect binaries that need updates
  declare -a BINARIES_TO_CHECK=()
  # Core binaries
  if [[ "$INSTALL_WEZTERM" == true ]]; then
    BINARIES_TO_CHECK+=("offline-packages/linux/wezterm.AppImage|wezterm|WezTerm|--version")
  fi
  BINARIES_TO_CHECK+=(
    "offline-packages/$OS/tmux-3.4-static-x86_64|tmux|tmux|-V"
    "offline-packages/$OS/fzf|fzf|fzf|--version"
    "offline-packages/$OS/fd|fd|fd|--version"
    "offline-packages/$OS/rg|rg|ripgrep|--version"
    "offline-packages/$OS/bat|bat|bat|--version"
    "offline-packages/$OS/starship|starship|starship|--version"
    "offline-packages/$OS/lsd|lsd|lsd (modern ls)|--version"
    "offline-packages/$OS/lazygit|lazygit|lazygit|--version"
    "offline-packages/$OS/zoxide|zoxide|zoxide|--version"
    "offline-packages/$OS/delta|delta|delta|--version"
    "offline-packages/$OS/difft|difft|difftastic|--version"
    "offline-packages/$OS/jq|jq|jq|--version"
    "offline-packages/$OS/btop|btop|btop|--version"
    "offline-packages/$OS/direnv|direnv|direnv|--version"
    "offline-packages/$OS/dust|dust|dust|--version"
    "offline-packages/$OS/gdu|gdu|gdu|--version"
    "offline-packages/$OS/mkcert|mkcert|mkcert|--version"
    "offline-packages/$OS/airgap-dev-kit|airgap-dev-kit|airgap-dev-kit|--version"
    "offline-packages/$OS/svu|svu|svu|--version"
  )
  
  # LSP servers
  [[ -f "offline-packages/$OS/lua-language-server" ]] && BINARIES_TO_CHECK+=("offline-packages/$OS/lua-language-server|lua-language-server|lua-language-server (Lua LSP)|--version")
  [[ -f "offline-packages/$OS/shellcheck" ]] && BINARIES_TO_CHECK+=("offline-packages/$OS/shellcheck|shellcheck|shellcheck (Shell linter)|--version")

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
    if [[ "$CLI_ONLY" == true ]]; then
      echo "CLI-only mode: installing all bundled CLI tools without prompting."
      for choice in "${INSTALL_CHOICES[@]}"; do
        IFS='|' read -r display spec <<< "$choice"
        SELECTED_BINARIES+=("$spec")
      done
    elif can_use_gum_prompts && [[ -f "$BIN_DIR/gum" ]]; then
      echo "Select binaries to install/update:"
      echo ""

      # Create choices file
      for choice in "${INSTALL_CHOICES[@]}"; do
        IFS='|' read -r display spec <<< "$choice"
        echo "$display"
      done > /tmp/binary_choices.txt

      # Run gum choose with multi-select
      if selected=$("$BIN_DIR"/gum choose --no-limit < /tmp/binary_choices.txt); then
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
      if ! is_interactive; then
        echo "Installing all selected-by-default binaries in non-interactive mode."
        for choice in "${INSTALL_CHOICES[@]}"; do
          IFS='|' read -r display spec <<< "$choice"
          SELECTED_BINARIES+=("$spec")
        done
      else
      read -p "Continue? [Y/n]: " -n 1 -r
      echo
      if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
        for choice in "${INSTALL_CHOICES[@]}"; do
          IFS='|' read -r display spec <<< "$choice"
          SELECTED_BINARIES+=("$spec")
        done
      fi
      fi
    fi

    # Install selected binaries
    echo ""
    echo "Installing binaries..."
    for binary_spec in "${SELECTED_BINARIES[@]}"; do
      IFS='|' read -r source dest name flag <<< "$binary_spec"
      # Use simplified install (no prompting since already selected)
      if [[ -f "$source" ]]; then
        # Backup if exists
        if [[ -f "$BIN_DIR/$dest" ]]; then
          backup_path="$BIN_DIR/$dest.backup-$(date +%Y%m%d-%H%M%S)"
          $USE_SUDO cp "$BIN_DIR/$dest" "$backup_path"
          install_executable "$source" "$BIN_DIR/$dest"
          echo "✓ $name installed"
          log_install "BINARY" "$BIN_DIR/$dest" "$backup_path" ""
        else
          install_executable "$source" "$BIN_DIR/$dest"
          echo "✓ $name installed"
          log_install "BINARY" "$BIN_DIR/$dest" "" ""
        fi
      fi
    done
  else
    echo ""
    echo "✓ All binaries are already up-to-date!"
  fi

  # Install Neovim binary and runtime
  echo ""
  echo "Installing Neovim..."
  if [[ -f offline-packages/linux/nvim-static-x86_64 ]]; then
    # Check if nvim already exists
    if [[ -f "$BIN_DIR/nvim" ]]; then
      existing_ver=$(get_version "$BIN_DIR/nvim" "--version")
      new_ver=$(get_version "offline-packages/linux/nvim-static-x86_64" "--version")

      # Skip if same version
      if [[ "$existing_ver" == "$new_ver" ]]; then
        echo "✓ Neovim (already up-to-date: $existing_ver)"
      elif prompt_overwrite "Neovim" "$existing_ver" "$new_ver" "$BIN_DIR/nvim"; then
        install_executable "offline-packages/linux/nvim-static-x86_64" "$BIN_DIR/nvim"
        log_install "BINARY" "$BIN_DIR/nvim" "" ""
        echo "✓ Neovim updated ($existing_ver → $new_ver)"
      else
        echo "⊘ Skipped Neovim"
      fi
    else
      # Fresh install
      install_executable "offline-packages/linux/nvim-static-x86_64" "$BIN_DIR/nvim"
      log_install "BINARY" "$BIN_DIR/nvim" "" ""
      echo "✓ Neovim installed"
    fi

    # Install Neovim runtime files (bundled alongside binary in official releases)
    if [[ -d offline-packages/linux/nvim-runtime ]]; then
      NVIM_RUNTIME_DEST="$HOME/.local/share/nvim/runtime"
      NVIM_RUNTIME_SOURCE="offline-packages/linux/nvim-runtime"
      if [[ -d "$NVIM_RUNTIME_SOURCE/runtime" && ! -d "$NVIM_RUNTIME_SOURCE/syntax" ]]; then
        NVIM_RUNTIME_SOURCE="$NVIM_RUNTIME_SOURCE/runtime"
      fi
      echo "  Installing Neovim runtime files..."
      mkdir -p "$(dirname "$NVIM_RUNTIME_DEST")"
      rm -rf "$NVIM_RUNTIME_DEST"
      cp -r "$NVIM_RUNTIME_SOURCE" "$NVIM_RUNTIME_DEST"
      log_install "DIRECTORY" "$NVIM_RUNTIME_DEST" "" ""
      echo "  ✓ Neovim runtime installed to $NVIM_RUNTIME_DEST"
    fi
  else
    echo "Warning: Neovim binary not found in offline-packages/linux/"
  fi

  # Install fzf shell integration scripts
  if [[ -d offline-packages/linux/fzf-scripts ]]; then
    echo ""
    echo "Installing fzf shell integration..."
    mkdir -p ~/.fzf/shell
    cp offline-packages/linux/fzf-scripts/* ~/.fzf/shell/
    echo "✓ fzf shell scripts installed to ~/.fzf/shell/"
  fi
fi

# Install Neovim plugins and LSP servers (if bundled)
if [[ -f offline-packages/lazy-plugins.tar.gz ]]; then
  echo "Installing Neovim plugins and LSP servers..."
  mkdir -p ~/.local/share/nvim
  tar -xzf offline-packages/lazy-plugins.tar.gz -C ~/.local/share/nvim/
  log_install "DIRECTORY" "$HOME/.local/share/nvim/lazy" "" ""
  if [[ -d ~/.local/share/nvim/mason ]]; then
    log_install "DIRECTORY" "$HOME/.local/share/nvim/mason" "" ""
    echo "✓ Neovim plugins and LSP servers installed"
  else
    echo "✓ Neovim plugins installed (LSP servers not included in this build)"
  fi
fi

# Install configs
echo ""
echo "Installing configuration files..."

if [[ ! -d config ]]; then
  echo "⚠ No config directory found, skipping config installation"
else
  # Ensure .config directory exists and has correct permissions
  mkdir -p ~/.config
  if [[ -d ~/.config ]] && [[ ! -w ~/.config ]]; then
    echo "  Fixing permissions on ~/.config..."
    $USE_SUDO chown -R "$(whoami):$(id -gn)" ~/.config
  fi

  # Each subdirectory of config/ is a Stow package whose contents mirror
  # the layout relative to $HOME (e.g. config/nvim/.config/nvim/ -> ~/.config/nvim/).
  # Non-directory entries (README.md, plugin-manifest.lua) are NOT packages and are skipped.

  # Collect package directories (non-hidden only; README.md etc. are files, not packages)
  packages=()
  while IFS= read -r -d '' pkg; do
    packages+=("$pkg")
  done < <(find config -maxdepth 1 -mindepth 1 -type d ! -name '.*' -print0)

  if [[ ${#packages[@]} -eq 0 ]]; then
    echo "  ⚠ No Stow packages found in config/ — skipping config install"
  else
    # Decide whether to use Stow or fall back to direct copy.
    STOW_CMD=""
    if command -v stow &>/dev/null; then
      STOW_CMD="stow"
    elif [[ -f "$BIN_DIR/stow" ]]; then
      STOW_CMD="$BIN_DIR/stow"
    fi

    if [[ -n "$STOW_CMD" ]]; then
      echo "  Using GNU Stow for symlink management..."
      stowed=0
      for pkg_path in "${packages[@]}"; do
        package_name=$(basename "$pkg_path")
        echo "  → Stowing package: $package_name"
        # Capture stow output; detect conflicts
        if stow_out=$($STOW_CMD -t ~ "$pkg_path" 2>&1); then
          rc=0
        else
          rc=$?
        fi
        if [[ $rc -eq 0 ]]; then
          echo "    ✓ $package_name stowed"
          log_install "STOW_PACKAGE" "$package_name" "" ""
          stowed=$((stowed + 1))
          continue
        fi
        # Handle conflicts by backing up existing targets, then retry
        if echo "$stow_out" | grep -q "existing target"; then
          echo "    ⚠ Conflicts detected. Backing up existing files..."
          echo "$stow_out" | grep "existing target" | while read -r line; do
            conflict_file=$(echo "$line" | grep -oP '(?<=existing target is )[^ ]+')
            if [[ -n "$conflict_file" ]]; then
              backup_path="${conflict_file}.backup-$(date +%Y%m%d-%H%M%S)"
              mv "$conflict_file" "$backup_path"
              log_install "CONFIG" "$conflict_file" "$backup_path" ""
            fi
          done
          if $STOW_CMD -t ~ "$pkg_path"; then
            echo "    ✓ $package_name stowed (after backup)"
            log_install "STOW_PACKAGE" "$package_name" "" ""
            stowed=$((stowed + 1))
          else
            echo "    ✗ Failed to stow $package_name"
          fi
        else
          echo "    ✗ Failed to stow $package_name: $stow_out"
        fi
      done

      # If nothing stowed, fall through to copy method
      if [[ $stowed -eq 0 ]]; then
        echo "  ⚠ Stow stowed 0 packages — falling back to direct copy"
        STOW_CMD=""
      fi
    fi

    if [[ -z "$STOW_CMD" ]]; then
      echo "  Using direct copy method for configs..."
      echo "  Note: Install 'stow' for symlink-based dotfile management."

      # Copy each package's contents into $HOME, preserving relative paths.
      for pkg_path in "${packages[@]}"; do
        package_name=$(basename "$pkg_path")
        echo "  → Copying package: $package_name"
        # Walk every entry inside the package (including hidden ones like .config, .tmux.conf)
        while IFS= read -r -d '' entry; do
          rel="${entry#"$pkg_path"/}"
          dest="$HOME/$rel"
          # Skip the package root itself
          [[ -z "$rel" || "$rel" == "." ]] && continue
          if [[ -d "$entry" ]]; then
            if [[ ! -d "$dest" ]]; then
              mkdir -p "$dest"
            fi
          elif [[ -f "$entry" ]]; then
            if [[ -e "$dest" ]]; then
              if cmp -s "$entry" "$dest"; then
                log_install "CONFIG" "$dest" "" ""
                continue
              fi
              backup_path="${dest}.backup-$(date +%Y%m%d-%H%M%S)"
              mv "$dest" "$backup_path"
              log_install "CONFIG" "$dest" "$backup_path" ""
            fi
            cp "$entry" "$dest" 2>/dev/null || {
              echo "    Permission issue detected, adjusting ownership..."
              $USE_SUDO cp "$entry" "$dest"
              $USE_SUDO chown "$(whoami):$(id -gn)" "$dest"
            }
            log_install "CONFIG" "$dest" "" ""
          fi
        done < <(find "$pkg_path" -mindepth 1 -print0)
      done
    fi
  fi

  echo "✓ Configuration files installed"
fi

# Fonts
echo ""

if [[ "$CLI_ONLY" == true ]]; then
  echo "CLI-only mode: skipping GUI font installation."
  INSTALL_FONTS=false
else
  # Detect if we're in a GUI environment
  if [[ -z "$DISPLAY" ]] && [[ -z "$WAYLAND_DISPLAY" ]]; then
    # No display detected - likely headless/SSH
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "ℹ Font Installation Info"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "No GUI display detected (headless/SSH environment)."
    echo ""
    echo "📌 Important: Fonts are rendered CLIENT-SIDE, not on the server!"
    echo ""
    echo "For LazyVim icons to display correctly when connecting via SSH:"
    echo "  1. Install JetBrainsMono Nerd Font on YOUR LOCAL MACHINE"
    echo "  2. Configure your local terminal emulator to use it"
    echo "  3. Font installation on this server is NOT needed"
    echo ""
    echo "Font location: fonts/JetBrainsMono.zip (copy to your local machine)"
    echo ""

    if can_use_gum_prompts && [[ -f "$BIN_DIR/gum" ]]; then
      if ! "$BIN_DIR"/gum confirm "Install fonts on this server anyway? (only needed if using local GUI terminal)"; then
        echo "⊘ Skipped font installation"
        INSTALL_FONTS=false
      else
        INSTALL_FONTS=true
      fi
    else
      if ! is_interactive; then
        echo "⊘ Skipped font installation"
        INSTALL_FONTS=false
      else
      read -p "Install fonts on this server anyway? (only needed if using local GUI terminal) [y/N]: " -n 1 -r
      echo
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        INSTALL_FONTS=true
      else
        echo "⊘ Skipped font installation"
        INSTALL_FONTS=false
      fi
      fi
    fi
  else
    # GUI environment detected
    echo "GUI display detected, installing fonts..."
    INSTALL_FONTS=true
  fi

  if [[ "$INSTALL_FONTS" == true ]]; then
    mkdir -p ~/.local/share/fonts
    if [[ -f fonts/JetBrainsMono.zip ]]; then
      if unzip -o fonts/JetBrainsMono.zip -d ~/.local/share/fonts 2>/dev/null; then
        echo "✓ Fonts extracted to ~/.local/share/fonts"
        log_install "DIRECTORY" "$HOME/.local/share/fonts/JetBrainsMono" "" ""

        # Update font cache if fc-cache is available
        if command -v fc-cache &>/dev/null; then
          echo "  Updating font cache..."
          fc-cache -fv >/dev/null 2>&1
          echo "✓ Font cache updated"
        else
          echo "⚠ fc-cache not found - fonts installed but not cached"
          echo "  Fonts will work after terminal restart"
          echo "  To enable font caching: install fontconfig package"
        fi
      else
        echo "⚠ Failed to extract fonts"
      fi
    else
      echo "⚠ Font file not found: fonts/JetBrainsMono.zip"
    fi
  fi
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
  echo "   Neovim: ~/.local/share/nvim/ (symlinked to $BIN_DIR/nvim)"
fi
echo "   Config: ~/.config/nvim/"
if [[ "$CLI_ONLY" != true ]]; then
  echo "   Fonts: ~/.local/share/fonts/"
fi
echo ""
echo "📋 Next Steps:"
echo ""
if [[ "$BIN_DIR" == "$HOME/.local/bin" ]] || [[ "$BIN_DIR" == "$HOME/bin" ]]; then
  echo "1. Add tools to your PATH (add to ~/.bashrc or ~/.zshrc):"
  if [[ "$BIN_DIR" == "$HOME/.local/bin" ]]; then
    echo "   export PATH=\"\$HOME/.local/bin:\$PATH\""
  else
    echo "   export PATH=\"\$HOME/bin:\$PATH\""
  fi
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
if [[ "$INSTALL_WEZTERM" == true ]]; then
  echo "   wezterm start -- tmux new-session nvim  # GUI environment"
else
  echo "   tmux new-session nvim  # Headless/SSH"
fi
echo ""
echo "📚 Installed tools:"
if [[ "$INSTALL_WEZTERM" == true ]]; then
  echo "   Terminal: wezterm (GUI), tmux (multiplexer)"
else
  echo "   Terminal: tmux (multiplexer)"
fi
echo "   Editor: nvim (with plugins)"
echo "   CLI Tools: fzf, fd, rg, bat, starship"
if [[ -f ~/bin/lsd ]]; then echo "   Optional: lsd"; fi
if [[ -f ~/bin/btop ]]; then echo "   Optional: btop"; fi
if [[ -f ~/bin/zoxide ]]; then echo "   Optional: zoxide"; fi
if [[ -f ~/bin/delta ]]; then echo "   Optional: delta"; fi
if [[ -f ~/bin/difft ]]; then echo "   Optional: difftastic"; fi
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
if [[ -z "$DISPLAY" ]]; then
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

# Track what we're adding for summary
declare -a SHELL_CONFIG_ITEMS=()

# Helper function to add configuration to shell RC file
add_to_shell_rc() {
  local rc_file="$1"
  local config_line="$2"
  local description="$3"

  if config_exists "$rc_file" "$config_line"; then
    SHELL_CONFIG_ITEMS+=("$description")
    return 0
  fi

  # Try to write, handle permission issues
  if ! echo "" >> "$rc_file" 2>/dev/null; then
    echo "  Permission denied, fixing ownership..."
    $USE_SUDO chown "$(whoami):$(id -gn)" "$rc_file"
  fi
  {
    echo ""
    echo "# Added by airgap-dev-kit installer"
    echo "$config_line"
  } >> "$rc_file"
  log_install "SHELL_CONFIG" "$rc_file" "" "$description"
  SHELL_CONFIG_ITEMS+=("$description")
  return 0
}

# Detect user's shell
DETECTED_SHELLS=()
if [[ "$CLI_ONLY" == true && "${AIRGAP_DEV_KIT_CONFIGURE_SHELLS:-}" == "0" ]]; then
  echo "CLI-only mode: skipped automatic shell configuration."
  echo "Unset AIRGAP_DEV_KIT_CONFIGURE_SHELLS or set it to 1 to enable shell setup."
else
[[ -f "$HOME/.bashrc" ]] && DETECTED_SHELLS+=("$HOME/.bashrc")
[[ -f "$HOME/.zshrc" ]] && DETECTED_SHELLS+=("$HOME/.zshrc")
[[ -f "$HOME/.config/fish/config.fish" ]] && DETECTED_SHELLS+=("$HOME/.config/fish/config.fish")

# If no RC files found, create one based on the user's actual login shell
if [[ ${#DETECTED_SHELLS[@]} -eq 0 ]]; then
  CURRENT_SHELL=$(basename "${SHELL:-bash}")
  echo "No existing shell RC files found. Detecting current shell: $CURRENT_SHELL"
  case "$CURRENT_SHELL" in
    zsh)
      touch "$HOME/.zshrc"
      DETECTED_SHELLS+=("$HOME/.zshrc")
      echo "  Created ~/.zshrc"
      ;;
    fish)
      mkdir -p "$HOME/.config/fish"
      touch "$HOME/.config/fish/config.fish"
      DETECTED_SHELLS+=("$HOME/.config/fish/config.fish")
      echo "  Created ~/.config/fish/config.fish"
      ;;
    *)
      touch "$HOME/.bashrc"
      DETECTED_SHELLS+=("$HOME/.bashrc")
      echo "  Created ~/.bashrc"
      ;;
  esac
fi

if [[ ${#DETECTED_SHELLS[@]} -eq 0 ]]; then
  echo "No shell configuration files found (.bashrc, .zshrc, config.fish)"
  echo "You can manually add configurations later using shell-setup-example.sh as reference"
else
  echo "Detected shell configuration files:"
  for shell_rc in "${DETECTED_SHELLS[@]}"; do
    echo "  • $(basename "$shell_rc")"
  done
  echo ""

  if [[ "$CLI_ONLY" == true ]]; then
    if [[ "${AIRGAP_DEV_KIT_CONFIGURE_SHELLS:-}" == "1" ]]; then
      echo "Configuring shells automatically because AIRGAP_DEV_KIT_CONFIGURE_SHELLS=1."
    elif ! is_interactive; then
      echo ""
      echo "Skipped automatic shell configuration in non-interactive CLI-only mode."
      echo "Set AIRGAP_DEV_KIT_CONFIGURE_SHELLS=1 to opt in."
      DETECTED_SHELLS=()
    else
      read -p "Patch shell RC files for Starship, zoxide, fzf, and PATH? [Y/n]: " -n 1 -r
      echo ""
      if [[ ! $REPLY =~ ^[Yy]$ ]] && [[ -n $REPLY ]]; then
        echo ""
        echo "Skipped automatic shell configuration."
        echo "See shell-setup-example.sh for manual setup instructions."
        DETECTED_SHELLS=()
      fi
    fi
  elif can_use_gum_prompts && [[ -f "$BIN_DIR/gum" ]]; then
    if ! "$BIN_DIR"/gum confirm "Configure shells automatically?"; then
      echo ""
      echo "Skipped automatic shell configuration."
      echo "See shell-setup-example.sh for manual setup instructions."
      DETECTED_SHELLS=()
    fi
  elif [[ "${AIRGAP_DEV_KIT_CONFIGURE_SHELLS:-}" == "1" ]]; then
    echo "Configuring shells automatically because AIRGAP_DEV_KIT_CONFIGURE_SHELLS=1."
  else
    if ! is_interactive; then
      echo ""
      echo "Skipped automatic shell configuration in non-interactive mode."
      echo "See shell-setup-example.sh for manual setup instructions."
      DETECTED_SHELLS=()
    fi
    if [[ ${#DETECTED_SHELLS[@]} -gt 0 ]]; then
      read -p "Configure shells automatically? [Y/n]: " -n 1 -r
      echo
      if [[ ! $REPLY =~ ^[Yy]$ ]] && [[ -n $REPLY ]]; then
        echo ""
        echo "Skipped automatic shell configuration."
        echo "See shell-setup-example.sh for manual setup instructions."
        DETECTED_SHELLS=()
      fi
    fi
  fi

  echo ""

  for SHELL_RC in "${DETECTED_SHELLS[@]}"; do
    echo "Configuring $(basename "$SHELL_RC")..."
    echo ""

    # Determine shell type
    SHELL_TYPE="bash"
    if [[ "$SHELL_RC" == *"zshrc"* ]]; then
      SHELL_TYPE="zsh"
    elif [[ "$SHELL_RC" == *"fish"* ]]; then
      SHELL_TYPE="fish"
    fi

    # PATH configuration (only if needed for user-local install)
    if [[ "$BIN_DIR" == "$HOME/.local/bin" ]] || [[ "$BIN_DIR" == "$HOME/bin" ]]; then
      if [[ "$SHELL_TYPE" == "fish" ]]; then
        if [[ "$BIN_DIR" == "$HOME/.local/bin" ]]; then
          add_to_shell_rc "$SHELL_RC" "set -gx PATH \$HOME/.local/bin \$PATH" "PATH configuration"
        else
          add_to_shell_rc "$SHELL_RC" "set -gx PATH \$HOME/bin \$PATH" "PATH configuration"
        fi
      else
        if [[ "$BIN_DIR" == "$HOME/.local/bin" ]]; then
          add_to_shell_rc "$SHELL_RC" "export PATH=\"\$HOME/.local/bin:\$PATH\"" "PATH configuration"
        else
          add_to_shell_rc "$SHELL_RC" "export PATH=\"\$HOME/bin:\$PATH\"" "PATH configuration"
        fi
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

    # VIMRUNTIME - needed when nvim is installed from the bundled standalone binary
    if [[ -d "$HOME/.local/share/nvim/runtime" ]]; then
      add_to_shell_rc "$SHELL_RC" "export VIMRUNTIME=\"\$HOME/.local/share/nvim/runtime\"" "VIMRUNTIME (Neovim runtime path)"
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
      # lsd
      if [[ -f "$BIN_DIR/lsd" ]]; then
        add_to_shell_rc "$SHELL_RC" "alias ls='lsd'" "lsd alias (modern ls)"
        add_to_shell_rc "$SHELL_RC" "alias ll='lsd -la'" "ll alias"
        add_to_shell_rc "$SHELL_RC" "alias tree='lsd --tree'" "tree alias"
      fi

      # bat
      if [[ -f "$BIN_DIR/bat" ]]; then
        add_to_shell_rc "$SHELL_RC" "alias cat='bat --paging=never'" "bat alias (syntax highlighting)"
      fi

      # fd
      if [[ -f "$BIN_DIR/fd" ]]; then
        add_to_shell_rc "$SHELL_RC" "alias find='fd'" "fd alias (faster find)"
      fi

      # ripgrep (no alias - different syntax than grep)
      # Users should use 'rg' directly

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

  echo ""
  
  # Show summary with gum if available
  if has_gum && [[ -f "$BIN_DIR/gum" ]]; then
    "$BIN_DIR"/gum style --border double --border-foreground 212 --padding "1 2" --bold "✓ Shell Configuration Complete!"
    echo ""
    "$BIN_DIR"/gum style --foreground 212 --bold "Configured the following:"
    echo ""
    for item in "${SHELL_CONFIG_ITEMS[@]}"; do
      "$BIN_DIR"/gum style --foreground 42 "  ✓ $item"
    done
  else
    echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${CYAN}║${RESET}  ${GREEN}${BOLD}✓ Shell Configuration Complete!${RESET}                     ${BOLD}${CYAN}║${RESET}"
    echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    echo -e "${BOLD}${MAGENTA}Configured the following:${RESET}"
    echo ""
    for item in "${SHELL_CONFIG_ITEMS[@]}"; do
      echo -e "  ${CHECK} ${item}"
    done
  fi
  
  echo ""
fi
fi

echo ""

if has_gum && [[ -f "$BIN_DIR/gum" ]]; then
  "$BIN_DIR"/gum style --border double --border-foreground 33 --padding "1 2" --bold "📝 Installation Tracking"
  echo ""
  echo "$("$BIN_DIR"/gum style --foreground 240 "Installation log saved to: ")$("$BIN_DIR"/gum style --foreground 51 "$INSTALL_LOG")"
  echo ""
  "$BIN_DIR"/gum style --bold "This log tracks everything installed and can be used for:"
  "$BIN_DIR"/gum style --foreground 51 "  ➜ Uninstalling with: ./uninstall.sh"
  "$BIN_DIR"/gum style --foreground 51 "  ➜ Reviewing what was installed"
  "$BIN_DIR"/gum style --foreground 51 "  ➜ Restoring from backups (if any were created)"
  echo ""
  echo "$("$BIN_DIR"/gum style --foreground 240 "To view the log: ")$("$BIN_DIR"/gum style --foreground 51 "cat $INSTALL_LOG")"
  echo ""
else
  echo -e "${BOLD}${BLUE}╔════════════════════════════════════════════════════════════╗${RESET}"
  echo -e "${BOLD}${BLUE}║${RESET}  ${YELLOW}📝 Installation Tracking${RESET}                            ${BOLD}${BLUE}║${RESET}"
  echo -e "${BOLD}${BLUE}╚════════════════════════════════════════════════════════════╝${RESET}"
  echo ""
  echo -e "${DIM}Installation log saved to:${RESET} ${CYAN}$INSTALL_LOG${RESET}"
  echo ""
  echo -e "${BOLD}This log tracks everything installed and can be used for:${RESET}"
  echo -e "  ${ARROW} Uninstalling with: ${CYAN}./uninstall.sh${RESET}"
  echo -e "  ${ARROW} Reviewing what was installed"
  echo -e "  ${ARROW} Restoring from backups (if any were created)"
  echo ""
  echo -e "${DIM}To view the log:${RESET}"
  echo -e "  ${CYAN}cat $INSTALL_LOG${RESET}"
  echo ""
fi

# Finalize log
echo "# Installation completed at $(date)" >> "$INSTALL_LOG"

# Final instructions - most prominent at the bottom
if [[ ${#SHELL_CONFIG_ITEMS[@]} -gt 0 ]]; then
  echo ""
  
  if has_gum && [[ -f "$BIN_DIR/gum" ]]; then
    "$BIN_DIR"/gum style --border double --border-foreground 42 --padding "1 2" --bold "★ NEXT STEPS - Apply Your Changes"
    echo ""
    "$BIN_DIR"/gum style --bold "To activate your new shell configuration, choose one:"
    echo ""
    "$BIN_DIR"/gum style --foreground 51 --bold "1. Restart your terminal (recommended)"
    "$BIN_DIR"/gum style --foreground 240 "   Close and reopen your terminal window"
    echo ""
    "$BIN_DIR"/gum style --foreground 51 --bold "2. Source only the config for your current shell:"
    "$BIN_DIR"/gum style --foreground 42 "   bash: source ~/.bashrc"
    "$BIN_DIR"/gum style --foreground 42 "   zsh:  source ~/.zshrc"
    "$BIN_DIR"/gum style --foreground 240 "   Do not source ~/.zshrc from bash."
    echo ""
    "$BIN_DIR"/gum style --border rounded --border-foreground 212 --padding "0 2" --bold "🚀 Enjoy your new development environment!"
    echo ""
  else
    echo -e "${BOLD}${GREEN}╔════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${GREEN}║${RESET}  ${STAR} ${BOLD}${YELLOW}NEXT STEPS - Apply Your Changes${RESET}                    ${BOLD}${GREEN}║${RESET}"
    echo -e "${BOLD}${GREEN}╚════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    echo -e "${BOLD}To activate your new shell configuration, choose one:${RESET}"
    echo ""
    echo -e "  ${BOLD}${CYAN}1.${RESET} ${BOLD}Restart your terminal${RESET} ${DIM}(recommended)${RESET}"
    echo -e "     ${DIM}Close and reopen your terminal window${RESET}"
    echo ""
    echo -e "  ${BOLD}${CYAN}2.${RESET} ${BOLD}Source only the config for your current shell:${RESET}"
    echo -e "     ${GREEN}bash: source ~/.bashrc${RESET}"
    echo -e "     ${GREEN}zsh:  source ~/.zshrc${RESET}"
    echo -e "     ${DIM}Do not source ~/.zshrc from bash.${RESET}"
    echo ""
    echo -e "${BOLD}${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${BOLD}${GREEN}🚀 Enjoy your new development environment!${RESET}"
    echo -e "${BOLD}${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
  fi
fi

echo ""
echo "Air-Gap Dev Kit version installed: ${KIT_VERSION}"
echo "To check for newer kit releases later, run 'make check-updates' (or ./scripts/check-updates.sh) on an online machine."
