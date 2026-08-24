#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$TMP_DIR/package/offline-packages/linux" "$TMP_DIR/home/.local/bin" "$TMP_DIR/home/.fzf/shell"

cp "$ROOT_DIR/install.sh" "$TMP_DIR/package/install.sh"
touch "$TMP_DIR/package/.airgap-cli-only"
cp /bin/sh "$TMP_DIR/package/offline-packages/linux/starship"
cp /bin/sh "$TMP_DIR/package/offline-packages/linux/zoxide"
cp /bin/sh "$TMP_DIR/package/offline-packages/linux/fd"
cp /bin/sh "$TMP_DIR/package/offline-packages/linux/lsd"
cp /bin/sh "$TMP_DIR/package/offline-packages/linux/bat"
cp /bin/sh "$TMP_DIR/package/offline-packages/linux/nvim-static-x86_64"
cp /bin/sh "$TMP_DIR/package/offline-packages/linux/tmux-3.4-static-x86_64"
touch "$TMP_DIR/home/.fzf/shell/key-bindings.bash"
touch "$TMP_DIR/home/.fzf/shell/completion.bash"
touch "$TMP_DIR/home/.fzf/shell/key-bindings.zsh"
touch "$TMP_DIR/home/.fzf/shell/completion.zsh"

cat > "$TMP_DIR/home/.bashrc" <<'EOF'
eval "$(starship init bash)"
PS1='legacy % '
EOF

cat > "$TMP_DIR/home/.zshrc" <<'EOF'
autoload -Uz promptinit
promptinit
prompt adam1
eval "$(starship init zsh)"
EOF

(
  cd "$TMP_DIR/package"
  PATH="/bin:/usr/bin" HOME="$TMP_DIR/home" OSTYPE=linux-gnu AIRGAP_DEV_KIT_CONFIGURE_SHELLS=1 ./install.sh
) > "$TMP_DIR/install.out" 2>&1

# shellcheck disable=SC2016
awk 'NF { line = $0 } END { print line }' "$TMP_DIR/home/.bashrc" | grep -F 'eval "$(zoxide init bash)"'
# shellcheck disable=SC2016
awk 'NF { line = $0 } END { print line }' "$TMP_DIR/home/.zshrc" | grep -F 'eval "$(zoxide init zsh)"'

# shellcheck disable=SC2016
if [[ $(grep -Fc 'eval "$(starship init bash)"' "$TMP_DIR/home/.bashrc") -ne 1 ]]; then
  echo "bash Starship init should be relocated, not duplicated" >&2
  exit 1
fi

# shellcheck disable=SC2016
if [[ $(grep -Fc 'eval "$(starship init zsh)"' "$TMP_DIR/home/.zshrc") -ne 1 ]]; then
  echo "zsh Starship init should be relocated, not duplicated" >&2
  exit 1
fi

# Zoxide init must be present exactly once and follow Starship in .bashrc, so
# its prompt hook is not replaced by a later initializer.
# shellcheck disable=SC2016
if [[ $(grep -Fc 'eval "$(zoxide init bash)"' "$TMP_DIR/home/.bashrc") -ne 1 ]]; then
  echo "bash Zoxide init should be relocated, not duplicated" >&2
  exit 1
fi

# shellcheck disable=SC2016
zoxide_line=$(grep -nF 'eval "$(zoxide init bash)"' "$TMP_DIR/home/.bashrc" | head -1 | cut -d: -f1)
# shellcheck disable=SC2016
starship_line=$(grep -nF 'eval "$(starship init bash)"' "$TMP_DIR/home/.bashrc" | head -1 | cut -d: -f1)
fzf_line=$(grep -nF 'source ~/.fzf/shell/key-bindings.bash' "$TMP_DIR/home/.bashrc" | head -1 | cut -d: -f1)

if [[ -z "$zoxide_line" || -z "$starship_line" ]]; then
  echo "Could not find zoxide or starship init lines" >&2
  exit 1
fi

if [[ "$zoxide_line" -le "$starship_line" ]]; then
  echo "Zoxide init (line $zoxide_line) must come after Starship init (line $starship_line)" >&2
  exit 1
fi

if [[ -n "$fzf_line" && "$fzf_line" -ge "$zoxide_line" ]]; then
  echo "fzf key bindings (line $fzf_line) must come before Zoxide init (line $zoxide_line)" >&2
  exit 1
fi

echo "Shell initializer order test passed"
