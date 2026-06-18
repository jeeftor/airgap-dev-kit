#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

mapfile -t lua_files < <(find config/nvim/.config/nvim -type f -name '*.lua' | sort)

if [[ "${#lua_files[@]}" -eq 0 ]]; then
  echo "No Neovim Lua config files found" >&2
  exit 1
fi

if command -v luac >/dev/null 2>&1; then
  for file in "${lua_files[@]}"; do
    luac -p "$file"
  done
elif command -v lua >/dev/null 2>&1; then
  for file in "${lua_files[@]}"; do
    lua -e 'assert(loadfile(arg[1]))' "$file"
  done
elif command -v nvim >/dev/null 2>&1; then
  for file in "${lua_files[@]}"; do
    nvim --headless -u NONE -i NONE -n -c "lua assert(loadfile(vim.fn.argv(0)))" -c qa "$file" >/dev/null
  done
elif [[ "$(uname -s)" == "Linux" && -x offline-packages/linux/nvim-static-x86_64 ]]; then
  for file in "${lua_files[@]}"; do
    offline-packages/linux/nvim-static-x86_64 --headless -u NONE -i NONE -n -c "lua assert(loadfile(vim.fn.argv(0)))" -c qa "$file" >/dev/null
  done
else
  echo "Skipping Neovim Lua syntax test: no lua, luac, or nvim parser available"
  exit 0
fi

echo "Neovim Lua config syntax passed"
