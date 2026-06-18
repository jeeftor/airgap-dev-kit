# Quick Command Reference

Copy-paste these commands for testing.

## Docker Interactive Testing

```bash
# Build image
docker build -f test/test-mason.Dockerfile -t airgap-mason-test .

# Start shell
docker run --rm -it -v $(pwd):/workspace airgap-mason-test bash
```

## Inside Container: LazyVim Plugins

```bash
# Clean slate
rm -rf ~/.config/nvim ~/.local/share/nvim ~/.local/state/nvim ~/.cache/nvim

# Install LazyVim starter
git clone --depth 1 https://github.com/LazyVim/starter ~/.config/nvim
rm -rf ~/.config/nvim/.git

# Install all plugins
nvim --headless "+Lazy! sync" +qa

# Check what got installed
echo "=== LazyVim Plugins ==="
ls -1 ~/.local/share/nvim/lazy | head -20
echo ""
echo "Total plugins: $(ls -1 ~/.local/share/nvim/lazy | wc -l)"
du -sh ~/.local/share/nvim/lazy

# Package them
tar -czf /workspace/lazyvim-plugins.tar.gz -C ~/.local/share/nvim lazy/
echo ""
echo "Package created:"
ls -lh /workspace/lazyvim-plugins.tar.gz
```

## Inside Container: Mason Packages (LSP/Formatters)

```bash
# Ensure LazyVim is set up first (see above)

# Install specific Mason packages
nvim --headless "+MasonInstall lua-language-server bash-language-server" +qa

# Check what got installed
echo "=== Mason Packages ==="
ls -1 ~/.local/share/nvim/mason/packages
du -sh ~/.local/share/nvim/mason/packages

# Package them
tar -czf /workspace/mason-packages.tar.gz -C ~/.local/share/nvim/mason packages/
echo ""
echo "Package created:"
ls -lh /workspace/mason-packages.tar.gz
```

## Complete One-Liner (All Steps)

```bash
# Inside container - install everything
rm -rf ~/.config/nvim ~/.local/share/nvim && \
git clone --depth 1 https://github.com/LazyVim/starter ~/.config/nvim && \
rm -rf ~/.config/nvim/.git && \
nvim --headless "+Lazy! sync" +qa && \
nvim --headless "+MasonInstall lua-language-server bash-language-server prettier stylua" +qa && \
tar -czf /workspace/lazyvim-plugins.tar.gz -C ~/.local/share/nvim lazy/ && \
tar -czf /workspace/mason-packages.tar.gz -C ~/.local/share/nvim/mason packages/ && \
echo "✅ Done! Check /workspace for tarballs"
```

## Make Commands (Host)

```bash
# Test plugin installation
make test

# Package plugins for air-gap
make test-package

# Interactive Docker shell
make test-interactive

# Force rebuild Docker image
make test-rebuild
```

## Air-Gap Machine: Install

```bash
# Extract LazyVim plugins
mkdir -p ~/.local/share/nvim
tar -xzf lazyvim-plugins.tar.gz -C ~/.local/share/nvim/

# Extract Mason packages
tar -xzf mason-packages.tar.gz -C ~/.local/share/nvim/mason/

# Copy config
cp -r config/nvim/.config/nvim ~/.config/

# Launch Neovim
nvim
```

## Verify Installation

```bash
# Inside Neovim
:Lazy          # Check plugins
:Mason         # Check LSP servers
:LspInfo       # Check LSP status
:checkhealth   # Check everything
```

## Testing Individual Plugins

```bash
# Test single plugin install
nvim --headless "+Lazy install telescope.nvim" +qa

# Test single Mason package
nvim --headless "+MasonInstall rust-analyzer" +qa

# Check logs
cat ~/.local/state/nvim/lazy.log
```

## Debugging

```bash
# Check what's installed
find ~/.local/share/nvim -type d -maxdepth 3

# Check plugin count
echo "Plugins: $(ls -1 ~/.local/share/nvim/lazy 2>/dev/null | wc -l)"
echo "Mason packages: $(ls -1 ~/.local/share/nvim/mason/packages 2>/dev/null | wc -l)"

# Check sizes
du -sh ~/.local/share/nvim/lazy
du -sh ~/.local/share/nvim/mason/packages

# Check Neovim version
nvim --version | head -1
```

## Common Mason Package Names

```bash
# LSP Servers
lua-language-server    # Lua
bash-language-server   # Bash
rust-analyzer          # Rust
gopls                  # Go
pyright               # Python
typescript-language-server  # TypeScript/JS
clangd                # C/C++
html-lsp              # HTML
css-lsp               # CSS
json-lsp              # JSON
yaml-language-server  # YAML

# Formatters
stylua                # Lua
prettier              # JS/TS/JSON/YAML/etc
black                 # Python
shfmt                 # Shell
rustfmt               # Rust

# Linters
shellcheck            # Shell
eslint_d              # JS/TS
flake8                # Python
```

## List All Available Mason Packages

```bash
nvim --headless "+lua print(vim.inspect(require('mason-registry').get_all_package_names()))" +qa
```
