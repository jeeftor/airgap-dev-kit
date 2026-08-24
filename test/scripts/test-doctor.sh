#!/usr/bin/env bash

# Verify doctor reports the installed package set and fails for a missing binary.
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$TMP_DIR/home/.local/bin" "$TMP_DIR/home/.config/nvim/lua/config" \
  "$TMP_DIR/home/.local/share/nvim/runtime/syntax" "$TMP_DIR/home/.local/share/nvim/lazy/lazy.nvim" \
  "$TMP_DIR/home/.local/share/nvim/lazy/LazyVim" "$TMP_DIR/home/.local/share/nvim/mason/node/bin" \
  "$TMP_DIR/home/.local/share/nvim/mason/packages" "$TMP_DIR/home/.local/state/airgap-dev-kit/transactions" \
  "$TMP_DIR/home/.fzf/shell"

while IFS= read -r package; do
  mkdir -p "$TMP_DIR/home/.local/share/nvim/mason/packages/$package"
done < <(awk '
  /^[[:space:]]*mason[[:space:]]*=/ { in_mason = 1; next }
  in_mason && /^[[:space:]]*lazyvim_extras[[:space:]]*=/ { exit }
  in_mason { sub(/--.*/, ""); if (match($0, /"[^"]+"/)) { print substr($0, RSTART + 1, RLENGTH - 2) } }
' "$ROOT_DIR/config/plugin-manifest.lua")

printf '%s\n' 'require("config.lazy")' > "$TMP_DIR/home/.config/nvim/init.lua"
printf '%s\n' 'return {}' > "$TMP_DIR/home/.config/nvim/lua/config/lazy.lua"
touch "$TMP_DIR/home/.local/share/nvim/lazy-lock.json"
for binary in nvim fd zoxide starship; do
  printf '%s\n' '#!/bin/sh' 'exit 0' > "$TMP_DIR/home/.local/bin/$binary"
  chmod +x "$TMP_DIR/home/.local/bin/$binary"
done
cat > "$TMP_DIR/home/.local/bin/uname" <<'EOF'
#!/bin/sh
if [ "${1:-}" = "-s" ]; then
  printf '%s\n' Linux
else
  /usr/bin/uname "$@"
fi
EOF
chmod +x "$TMP_DIR/home/.local/bin/uname"
cp "$TMP_DIR/home/.local/bin/nvim" "$TMP_DIR/home/.local/share/nvim/mason/node/bin/node"
for file in key-bindings.bash completion.bash key-bindings.zsh completion.zsh; do touch "$TMP_DIR/home/.fzf/shell/$file"; done

cat > "$TMP_DIR/home/.bashrc" <<'EOF'
export VIMRUNTIME="$HOME/.local/share/nvim/runtime"
source ~/.fzf/shell/key-bindings.bash
source ~/.fzf/shell/completion.bash
eval "$(starship init bash)"
eval "$(zoxide init bash)"
EOF
cat > "$TMP_DIR/home/.zshrc" <<'EOF'
export VIMRUNTIME="$HOME/.local/share/nvim/runtime"
source ~/.fzf/shell/key-bindings.zsh
source ~/.fzf/shell/completion.zsh
eval "$(starship init zsh)"
eval "$(zoxide init zsh)"
EOF
printf 'BINARY|%s||test\n' "$TMP_DIR/home/.local/bin/nvim" > "$TMP_DIR/home/.airgap-dev-kit-install.log"
printf 'BINARY|%s||test\n' "$TMP_DIR/home/.local/bin/fd" >> "$TMP_DIR/home/.airgap-dev-kit-install.log"
printf 'BINARY|%s||test\n' "$TMP_DIR/home/.local/bin/zoxide" >> "$TMP_DIR/home/.airgap-dev-kit-install.log"
printf 'BINARY|%s||test\n' "$TMP_DIR/home/.local/bin/starship" >> "$TMP_DIR/home/.airgap-dev-kit-install.log"

HOME="$TMP_DIR/home" PATH="$TMP_DIR/home/.local/bin:$PATH" "$ROOT_DIR/scripts/airgap-dev-kit" doctor > "$TMP_DIR/doctor.out"
rg -Fq 'Checked 4 installed binaries' "$TMP_DIR/doctor.out"
rg -Fq 'Mason package: gopls' "$TMP_DIR/doctor.out"
rg -Fq 'Neovim headless startup and lazy.nvim load succeeded' "$TMP_DIR/doctor.out"
rg -Fq 'bash initializer order: Starship before zoxide' "$TMP_DIR/doctor.out"
rg -Fq 'zsh initializer order: Starship before zoxide' "$TMP_DIR/doctor.out"

rm "$TMP_DIR/home/.local/bin/fd"
if HOME="$TMP_DIR/home" PATH="$TMP_DIR/home/.local/bin:$PATH" "$ROOT_DIR/scripts/airgap-dev-kit" doctor > "$TMP_DIR/doctor-missing.out" 2>&1; then
  echo 'doctor should fail when an installed binary disappears' >&2
  exit 1
fi
rg -Fq 'fd missing or not executable' "$TMP_DIR/doctor-missing.out"

echo 'doctor test passed'
