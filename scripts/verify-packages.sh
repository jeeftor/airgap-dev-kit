#!/bin/sh
# Verify the offline payload with color when Gum is available on an interactive terminal.
set -u

GUM=""
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && command -v gum >/dev/null 2>&1; then
  GUM=$(command -v gum)
fi
failures=0

heading() {
  if [ -n "$GUM" ]; then "$GUM" style --foreground 212 --bold "$1"; else printf '%s\n' "$1"; fi
}

ok() {
  if [ -n "$GUM" ]; then "$GUM" style --foreground 42 "  ✓ $1"; else printf '  ✓ %s\n' "$1"; fi
}

warn() {
  if [ -n "$GUM" ]; then "$GUM" style --foreground 214 "  ⚠ $1"; else printf '  ⚠ %s\n' "$1"; fi
}

bad() {
  if [ -n "$GUM" ]; then "$GUM" style --foreground 196 "  ✗ $1"; else printf '  ✗ %s\n' "$1"; fi
  failures=$((failures + 1))
}

check_executable() {
  path=$1
  label=$2
  if file "$path" 2>/dev/null | grep -q executable; then ok "$label"; else bad "$label - missing or invalid"; fi
}

heading "Verifying offline payload"
printf '\n'
heading "Core Linux binaries"
check_executable offline-packages/linux/wezterm.AppImage wezterm.AppImage
check_executable offline-packages/linux/tmux-3.4-static-x86_64 tmux-3.4-static-x86_64
check_executable offline-packages/linux/nvim-static-x86_64 nvim-static-x86_64
if [ -d offline-packages/linux/nvim-runtime ]; then ok nvim-runtime/; else bad "nvim-runtime/ - missing (re-run make update-linux to download)"; fi

printf '\n'
heading "CLI tools"
for tool in fzf fd rg bat starship btop lsd zoxide delta difft direnv dust gdu usbtree glow broot fastfetch mkcert lazygit jq gping lua-language-server shellcheck svu; do
  check_executable "offline-packages/linux/$tool" "$tool"
done
warn "gopls and other LSPs are installed via Mason (not verified here)"

printf '\n'
heading "Fonts"
if file fonts/JetBrainsMono.zip 2>/dev/null | grep -q 'Zip\|archive'; then ok JetBrainsMono.zip; else bad "JetBrainsMono.zip - missing or invalid"; fi

printf '\n'
printf '\n'
if [ "$failures" -gt 0 ]; then
  if [ -n "$GUM" ]; then "$GUM" style --foreground 196 --bold "✗ Verification failed: $failures item(s) need attention."; else echo "✗ Verification failed. Please address the missing binaries above."; fi
  exit 1
fi
if [ -n "$GUM" ]; then "$GUM" style --border double --border-foreground 42 --padding "0 1" --bold "✓ Verification passed — all required binaries are present."; else echo "✓ Verification passed. All required binaries present."; fi
