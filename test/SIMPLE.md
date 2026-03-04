# Simple LazyVim Plugin Installation for Air-Gap

## The Simple Answer

**Where do LazyVim plugins get installed?**
- **Location:** `~/.local/share/nvim/lazy/`
- **How:** `nvim --headless "+Lazy! sync" +qa`

## Three Commands to Package Plugins

```bash
# 1. Install plugins in Docker
make test

# 2. Package plugins for air-gap
make test-package

# 3. Done! You'll have: offline-packages/lazyvim-plugins.tar.gz
```

## Manual Step-by-Step (Inside Docker)

```bash
# Start container
docker run --rm -it -v $(pwd):/workspace airgap-mason-test bash

# Inside container:
rm -rf ~/.config/nvim ~/.local/share/nvim
git clone --depth 1 https://github.com/LazyVim/starter ~/.config/nvim
rm -rf ~/.config/nvim/.git
nvim --headless "+Lazy! sync" +qa

# Check results
ls ~/.local/share/nvim/lazy    # Plugins are here!
du -sh ~/.local/share/nvim/lazy # See size

# Package them
cd ~/.local/share/nvim
tar -czf /workspace/lazyvim-plugins.tar.gz lazy/
```

## On Air-Gapped Machine

```bash
# Extract plugins
mkdir -p ~/.local/share/nvim
tar -xzf lazyvim-plugins.tar.gz -C ~/.local/share/nvim

# Copy your config
cp -r airgap-dev-kit/config/.config/nvim ~/.config/

# Done! LazyVim will use the pre-installed plugins
```

## Key Config Setting

Your `config/.config/nvim/lua/config/lazy.lua` already has:

```lua
install = {
  missing = false,  -- Don't auto-install missing plugins (air-gap mode)
},
```

This tells LazyVim to use pre-installed plugins and not try to download anything.

## What About Mason (LSP/Formatters)?

Mason packages are separate:
- **Location:** `~/.local/share/nvim/mason/packages/`
- **Install:** `nvim --headless "+MasonInstall lua-language-server" +qa`
- **Package:** `tar -czf mason-packages.tar.gz -C ~/.local/share/nvim/mason packages/`

LazyVim plugins ≠ Mason packages. They're different systems.

## Adding New Plugins or LSP Servers

**See:** `docs/ADDING-PLUGINS-AND-LSPS.md` for complete guide.

### Quick: Add a Plugin

1. Edit `config/.config/nvim/lua/plugins/my-plugins.lua`:
```lua
return {
  { "folke/zen-mode.nvim" },
}
```

2. Run: `make test-package`
3. Done! Plugin included in tarball.

### Quick: Add an LSP Server

1. Edit `config/.config/nvim/lua/plugins/airgap-lsp.lua`:
```lua
{
  "williamboman/mason-lspconfig.nvim",
  opts = {
    ensure_installed = {
      "lua_ls",
      "rust_analyzer",  -- Add this!
    },
  },
}
```

2. Install: `nvim --headless "+Lazy! sync" +qa`
3. Package: `tar -czf mason-packages.tar.gz -C ~/.local/share/nvim/mason packages/`
