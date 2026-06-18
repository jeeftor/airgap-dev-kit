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
awk 'NF { line = $0 } END { print line }' "$TMP_DIR/home/.bashrc" | grep -F 'eval "$(starship init bash)"'
# shellcheck disable=SC2016
awk 'NF { line = $0 } END { print line }' "$TMP_DIR/home/.zshrc" | grep -F 'eval "$(starship init zsh)"'

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

echo "Starship terminal init test passed"
