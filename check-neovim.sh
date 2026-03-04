#!/bin/bash
# Quick script to check Neovim version in the container

echo "Checking Neovim version in container..."
docker run --rm airgap-mason-test nvim --version
echo ""
echo "Checking if Neovim meets lazy.nvim requirements..."
docker run --rm airgap-mason-test bash -c "nvim --version | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1 | awk '{if (\$1 >= 0.8) print \"✅ Neovim version OK\"; else print \"❌ Neovim version too old: \" \$1}'"
