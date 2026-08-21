# Air-Gap Dev Kit Architecture

## System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     Single Source of Truth                       │
│                  config/plugin-manifest.lua                      │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ plugins = { ... }      ← LazyVim plugins                   │ │
│  │ mason = { ... }        ← LSP servers, formatters, linters  │ │
│  │ lazyvim_extras = {...} ← Language packs                    │ │
│  └────────────────────────────────────────────────────────────┘ │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       ↓
        ┌──────────────────────────────┐
        │ scripts/install-from-manifest.sh │
        │ (Reads manifest, installs all) │
        └──────────┬─────────┬───────────┘
                   │         │
        ┌──────────┘         └──────────┐
        ↓                                ↓
┌───────────────────┐          ┌────────────────────┐
│  Local Testing    │          │  GitHub Actions    │
│  (Docker)         │          │  (Cloud)           │
│                   │          │                    │
│ make test-manifest│          │ .github/workflows/ │
│        ↓          │          │ release.yml        │
│   airgap-mason-   │          │        ↓           │
│   test container  │          │   ubuntu-latest    │
│        ↓          │          │        ↓           │
│  Install plugins  │          │  Install plugins   │
│        ↓          │          │        ↓           │
│  make test-package│          │  Upload artifacts  │
│  -manifest        │          │                    │
└────────┬──────────┘          └─────────┬──────────┘
         │                               │
         └───────────┬───────────────────┘
                     ↓
         ┌───────────────────────┐
         │  Packaged Outputs     │
         │                       │
         │ lazyvim-plugins.tar.gz│
         │ mason-packages.tar.gz │
         │ MANIFEST.txt          │
         └───────────┬───────────┘
                     │
                     ↓
         ┌───────────────────────┐
         │  Air-Gap Machine      │
         │                       │
         │ tar -xzf ...          │
         │ cp config ...         │
         │ nvim                  │
         └───────────────────────┘
```

## Component Details

### 1. Configuration Layer

```
config/
├── plugin-manifest.lua       ← Single source of truth
│   ├── plugins              ← LazyVim plugins (GitHub repos)
│   ├── mason                ← LSP/formatters/linters
│   └── lazyvim_extras       ← LazyVim language packs
│
└── .config/nvim/            ← Neovim configuration
    ├── init.lua
    ├── lua/
    │   ├── config/
    │   │   ├── lazy.lua     ← Sets install.missing = false
    │   │   └── ...
    │   └── plugins/
    │       ├── airgap-lsp.lua    ← Legacy config (optional)
    │       └── ...
```

### 2. Installation Layer

```
scripts/
└── install-from-manifest.sh
    │
    ├─→ Reads plugin-manifest.lua
    ├─→ Clones LazyVim starter
    ├─→ Generates config from manifest
    ├─→ Runs: nvim --headless "+Lazy! sync" +qa
    ├─→ Installs Mason packages
    └─→ Reports summary
```

### 3. Testing Layer

```
test/
├── test-mason.Dockerfile      ← Docker environment
│   ├── Ubuntu 24.04
│   ├── Neovim v0.11.2 (built from source)
│   ├── Git, Node.js, ripgrep, fd, fzf
│   └── Build tools
│
├── test-with-manifest.sh      ← Test wrapper
│   └─→ Calls install-from-manifest.sh
│
└── Makefile targets
    ├── test-manifest          ← Test installation
    └── test-package-manifest  ← Package everything
```

### 4. GitHub Actions Layer

```
.github/workflows/
└── release.yml
    │
    ├─→ Trigger: SemVer tag push only
    ├─→ Build the Linux kit from committed inputs
    ├─→ Bundle LazyVim and Mason payloads
    ├─→ Verify archive layout and checksum
    └─→ Create the GitHub Release
```

### 5. Deployment Layer

```
Air-Gap Machine:
~/.local/share/nvim/
├── lazy/                      ← LazyVim plugins (extracted)
└── mason/
    └── packages/              ← Mason packages (extracted)

~/.config/nvim/                ← Config (copied)
├── init.lua
└── lua/
    └── config/
        └── lazy.lua           ← install.missing = false
```

## Data Flow

### Development Flow

```
Developer
    │
    ├─→ Edit config/plugin-manifest.lua
    │       ├─→ Add plugin: "author/plugin"
    │       └─→ Add LSP: "rust_analyzer"
    │
    ├─→ make test-manifest
    │       ├─→ Docker builds
    │       ├─→ Installs plugins
    │       └─→ Shows summary
    │
    ├─→ make test-package-manifest
    │       ├─→ Extracts from Docker
    │       └─→ Creates tarballs
    │
    └─→ git push
            └─→ GitHub Actions builds
                    └─→ Uploads artifacts
```

### Deployment Flow

```
Online Machine (GitHub Actions or local)
    │
    ├─→ Reads plugin-manifest.lua
    ├─→ Downloads plugins from internet
    ├─→ Packages to tarballs
    └─→ Outputs:
            ├─→ lazyvim-plugins.tar.gz
            └─→ mason-packages.tar.gz

Transfer via USB/sneakernet
    │
    ↓

Air-Gap Machine
    │
    ├─→ Extract tarballs
    ├─→ Copy config
    └─→ Launch nvim
            └─→ Plugins work offline!
```

## Plugin Storage Locations

### LazyVim Plugins

```
~/.local/share/nvim/lazy/
├── lazy.nvim/                 ← Plugin manager
├── LazyVim/                   ← LazyVim framework
├── telescope.nvim/            ← Example plugin
├── which-key.nvim/
└── ...                        ← 50+ plugins
```

**Managed by:** lazy.nvim
**Installed by:** `nvim --headless "+Lazy! sync" +qa`
**Defined in:** `plugin-manifest.lua` → `plugins.extras`

### Mason Packages

```
~/.local/share/nvim/mason/packages/
├── lua-language-server/       ← LSP server
├── bash-language-server/
├── prettier/                  ← Formatter
├── stylua/
└── shellcheck/                ← Linter
```

**Managed by:** Mason
**Installed by:** `nvim --headless "+MasonInstall <pkg>" +qa`
**Defined in:** `plugin-manifest.lua` → `mason.lsp_servers`, `mason.formatters`, `mason.linters`

## Configuration Flow

### Online Installation (with internet)

```
1. User edits plugin-manifest.lua
2. Lazy.nvim downloads plugins from GitHub
3. Mason downloads packages from mason-registry
4. Everything cached locally
```

### Air-Gap Installation (no internet)

```
1. Plugins pre-installed to ~/.local/share/nvim/lazy/
2. Mason packages pre-installed to ~/.local/share/nvim/mason/packages/
3. Config has: install.missing = false
4. LazyVim uses pre-installed plugins
5. Mason uses pre-installed packages
```

## Key Design Decisions

### Why Lua for Manifest?

- Native to Neovim
- Easy to parse
- Supports comments
- Can be loaded directly by Neovim
- Allows for future extensibility

### Why Build Neovim from Source?

**Testing:** System Neovim (via apt) may be outdated. LazyVim requires recent versions.

**Production:** Static binary is fine - we only need plugins to work, not Neovim itself.

### Why Separate lazy/ and mason/?

**Different purposes:**
- `lazy/` = Editor features (UI, navigation, etc.)
- `mason/` = Language tools (LSP, formatters, etc.)

**Different managers:**
- `lazy.nvim` manages lazy/
- `Mason` manages mason/

**Both needed for complete dev environment.**

### Why Docker for Testing?

- Clean, reproducible environment
- Can test without polluting host
- Same environment as GitHub Actions (Ubuntu)
- Easy to rebuild
- Cached layers = fast iteration

## Extensibility

### Adding New Package Types

Edit `plugin-manifest.lua`:

```lua
return {
  plugins = { ... },
  mason = { ... },

  -- Add new category
  dap_adapters = {
    "debugpy",
    "codelldb",
  },
}
```

Update `scripts/install-from-manifest.sh` to handle new category.

### Adding Custom Config

```lua
return {
  plugins = { ... },

  custom_settings = {
    theme = "catppuccin",
    font_size = 14,
    -- Your custom settings
  },
}
```

Scripts can read `manifest.custom_settings`.

### Adding Validation

```lua
-- config/plugin-manifest.lua
local manifest = {
  plugins = { ... },
  mason = { ... },
}

-- Validation
assert(manifest.plugins, "plugins field required")
assert(manifest.mason.lsp_servers, "lsp_servers required")

return manifest
```

## Benefits Recap

### 🎯 Single Source of Truth
One file defines everything. No duplicates.

### 🧪 Testable
Test locally before deploying. Same code everywhere.

### 🔄 Automatable
GitHub Actions builds packages automatically.

### 📦 Portable
Tarballs work on any Linux/macOS machine.

### 🔒 Air-Gap Ready
Works offline with pre-installed packages.

### 🛠️ Maintainable
Easy to understand, easy to modify.

### 🤝 Collaborative
Team can edit manifest together.

### 📊 Versioned
Git tracks all changes to plugin list.

## Future Enhancements

- [ ] Version pinning (lock plugin versions)
- [ ] Dependency resolution
- [ ] Checksum verification
- [ ] Auto-update manifest from installed plugins
- [ ] Plugin conflict detection
- [ ] Size optimization (remove unused plugins)
- [ ] Multiple manifest profiles (minimal, full, team-specific)
