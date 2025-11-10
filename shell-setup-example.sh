#!/usr/bin/env bash
# Air-Gap Dev Kit - Shell Setup Example
# Add these lines to your ~/.bashrc or ~/.zshrc

# ============================================
# PATH - Add ~/bin to PATH
# ============================================
export PATH="$HOME/bin:$PATH"

# ============================================
# Modern CLI Tool Aliases
# ============================================

# lsd - Modern ls replacement with icons
if command -v lsd &>/dev/null; then
  alias ls='lsd'
  alias ll='lsd -la'
  alias la='lsd -a'
  alias lt='lsd --tree'
  alias l='lsd -l'
fi

# bat - Cat with syntax highlighting
if command -v bat &>/dev/null; then
  alias cat='bat --paging=never'
  alias bcat='bat'  # Keep original bat behavior
  export BAT_THEME="Catppuccin-mocha"  # Or your preferred theme
fi

# fd - Fast find alternative
if command -v fd &>/dev/null; then
  alias find='fd'
fi

# ripgrep - Fast grep alternative
if command -v rg &>/dev/null; then
  alias grep='rg'
fi

# ============================================
# Starship Prompt
# ============================================
if command -v starship &>/dev/null; then
  eval "$(starship init bash)"  # Change to 'zsh' if using zsh
fi

# ============================================
# Zoxide - Smarter cd
# ============================================
if command -v zoxide &>/dev/null; then
  eval "$(zoxide init bash)"  # Change to 'zsh' if using zsh
  # Now use 'z <directory>' to jump around
  # Example: z projects  -> jumps to most-used directory matching "projects"
fi

# ============================================
# FZF Configuration
# ============================================
if command -v fzf &>/dev/null; then
  # Use fd for fzf if available
  if command -v fd &>/dev/null; then
    export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  fi

  # FZF keybindings (optional)
  # Ctrl+T - Paste selected file path
  # Ctrl+R - Search command history
  # Alt+C  - cd into selected directory

  # Add preview window with bat
  if command -v bat &>/dev/null; then
    export FZF_DEFAULT_OPTS="--preview 'bat --color=always --style=numbers --line-range=:500 {}'"
  fi
fi

# ============================================
# Git Delta (better diffs)
# ============================================
if command -v delta &>/dev/null; then
  # Configure in ~/.gitconfig:
  # [core]
  #     pager = delta
  # [interactive]
  #     diffFilter = delta --color-only
  # [delta]
  #     navigate = true
  #     side-by-side = true
  #     line-numbers = true
  true  # Delta is configured via gitconfig
fi

# ============================================
# Neovim
# ============================================
# Make nvim the default editor
if command -v nvim &>/dev/null; then
  export EDITOR='nvim'
  export VISUAL='nvim'
  alias vim='nvim'
  alias vi='nvim'
fi

# ============================================
# Tmux Auto-start (optional)
# ============================================
# Automatically start tmux on shell login
# if command -v tmux &>/dev/null && [ -z "$TMUX" ]; then
#   tmux attach-session -t default || tmux new-session -s default
# fi

# ============================================
# Additional Aliases
# ============================================

# Quick navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# Git shortcuts (if you use git)
alias g='git'
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph --decorate'

# System info
if command -v btop &>/dev/null; then
  alias top='btop'
  alias htop='btop'
fi

# ============================================
# Helpful Functions
# ============================================

# Quick search and edit with fzf + nvim
if command -v fzf &>/dev/null && command -v nvim &>/dev/null; then
  vf() {
    local file
    file=$(fzf --preview 'bat --color=always --style=numbers {}')
    [ -n "$file" ] && nvim "$file"
  }
fi

# Create directory and cd into it
mkcd() {
  mkdir -p "$1" && cd "$1"
}

# Extract archives
extract() {
  if [ -f "$1" ]; then
    case "$1" in
      *.tar.gz|*.tgz)  tar -xzf "$1" ;;
      *.tar.bz2|*.tbz) tar -xjf "$1" ;;
      *.tar.xz)        tar -xJf "$1" ;;
      *.zip)           unzip "$1" ;;
      *.gz)            gunzip "$1" ;;
      *)               echo "Unknown archive format: $1" ;;
    esac
  else
    echo "File not found: $1"
  fi
}

# ============================================
# Welcome Message (optional)
# ============================================
echo "🚀 Air-Gap Dev Kit loaded!"
echo "   Tools: wezterm, tmux, nvim, fzf, fd, rg, bat, lsd, starship"
echo "   Type 'alias' to see all available shortcuts"
