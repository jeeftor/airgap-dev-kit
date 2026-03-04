# Summary: DRY Plugin Management System

## What We Built

A **Don't Repeat Yourself (DRY)** system for managing Neovim plugins and LSP servers in air-gapped environments.

## Key Innovation

**Before:** Plugin lists scattered across test scripts, workflows, configs
**After:** ONE file (`config/plugin-manifest.lua`) controls everything

## Files Created

### Core System
1. **`config/plugin-manifest.lua`** - Single source of truth for all plugins
2. **`scripts/install-from-manifest.sh`** - Installs everything from manifest
3. **`test/test-with-manifest.sh`** - Test wrapper for Docker

### Makefile Targets
4. **`make test-manifest`** - Test plugin installation from manifest
5. **`make test-package-manifest`** - Package plugins for production

### GitHub Actions
6. **`.github/workflows/build-nvim-packages.yml`** - Automated builds

### Documentation
7. **`docs/QUICK-START-DRY.md`** - 2-minute quick start
8. **`docs/DRY-WORKFLOW.md`** - Complete guide
9. **`docs/ARCHITECTURE.md`** - System architecture
10. **`docs/ADDING-PLUGINS-AND-LSPS.md`** - How to add plugins (updated)

## Answering Your Questions

### Q1: How do I get a customized plugin list I can easily edit?

**Answer:** Edit `config/plugin-manifest.lua`

```lua
return {
  plugins = {
    extras = {
      "folke/zen-mode.nvim",  -- Add any plugin!
    },
  },
  mason = {
    lsp_servers = {
      "rust_analyzer",        -- Add any LSP!
    },
  },
}
```

**Test:** `make test-manifest`
**Package:** `make test-package-manifest`
**Done!**

### Q2: How do we get better DRY?

**Answer:** Manifest-based approach

```
config/plugin-manifest.lua
         ↓
scripts/install-from-manifest.sh
         ↓
    ┌────┴────┐
    ↓         ↓
  Docker    GitHub Actions
    ↓         ↓
  Production packages
```

**Same manifest used everywhere!**

### Q3: Can we mount configs into Docker?

**Answer:** Yes! Already implemented:

```bash
docker run --rm \
  -v $(pwd):/workspace \
  -e MANIFEST_PATH=/workspace/config/plugin-manifest.lua \
  airgap-mason-test bash
```

The manifest is mounted and used directly.

### Q4: Can we reuse local-dev-test for final product?

**Answer:** Yes! That's the whole point:

1. **Local testing** uses `scripts/install-from-manifest.sh`
2. **GitHub Actions** uses same script
3. **Production package** created from same manifest

**No duplication. Same code everywhere.**

## Usage Examples

### Example 1: Add Rust Support

```bash
# Edit manifest
vim config/plugin-manifest.lua
# Add: "lazyvim.plugins.extras.lang.rust"
# Add: lsp_servers = { "rust_analyzer" }
# Add: formatters = { "rustfmt" }

# Test
make test-manifest

# Package
make test-package-manifest

# Push (triggers GitHub Actions)
git push
```

### Example 2: Customize for Your Team

```bash
# Fork repo
# Edit config/plugin-manifest.lua to your needs
# Push to GitHub
# GitHub Actions builds custom packages
# Download artifacts
# Distribute to team
```

### Example 3: Test Interactively

```bash
# Start container with custom manifest
docker run --rm -it \
  -v $(pwd):/workspace \
  -e MANIFEST_PATH=/workspace/config/plugin-manifest.lua \
  airgap-mason-test bash

# Inside container
/workspace/scripts/install-from-manifest.sh

# Inspect results
ls ~/.local/share/nvim/lazy
ls ~/.local/share/nvim/mason/packages
```

## Benefits

### ✅ DRY (Don't Repeat Yourself)
- Edit one file, not five
- No duplicate plugin lists
- Single source of truth

### ✅ Easy Customization
- Clear manifest format
- Comments supported
- Easy to understand

### ✅ Testable Locally
- Docker-based testing
- Same environment as CI
- Fast iteration

### ✅ Production Ready
- Same code in test and prod
- GitHub Actions automation
- Predictable results

### ✅ Air-Gap Compatible
- Pre-install everything
- Package to tarballs
- Deploy offline

### ✅ Maintainable
- Self-documenting
- Version controlled
- Team-friendly

## Architecture Principles

### 1. Configuration as Code
Manifest is code, lives in Git, is versioned.

### 2. Build Once, Run Anywhere
Same packages work in Docker, CI, production, air-gap.

### 3. Fail Fast
Test locally before pushing. Catch issues early.

### 4. Separation of Concerns
- Manifest = WHAT to install
- Scripts = HOW to install
- Docker/CI = WHERE to install

### 5. Least Surprise
Obvious file names, clear structure, documented behavior.

## Comparison to Alternatives

### Alternative 1: Manual Commands

**Problem:** Can't automate, error-prone, not reproducible
**Our solution:** Script-based, automated, tested

### Alternative 2: Separate Config Files

**Problem:** Duplication, sync issues, maintenance burden
**Our solution:** Single manifest, used everywhere

### Alternative 3: Hard-coded Lists

**Problem:** Hard to customize, requires code changes
**Our solution:** Data-driven, easy to edit

## What's Different from Before?

### Before
```
test/test-mason.sh
  - Hard-coded: "lua-language-server"

.github/workflows/build.yml
  - Hard-coded: "lua-language-server"

config/.config/nvim/lua/plugins/airgap-lsp.lua
  - Hard-coded: "lua_ls"

❌ Three places to edit!
❌ Easy to get out of sync!
```

### After
```
config/plugin-manifest.lua
  - lsp_servers = { "lua_ls" }

scripts/install-from-manifest.sh
  - Reads manifest

Docker + CI + Production
  - All use same script

✅ One place to edit!
✅ Always in sync!
```

## Quick Command Reference

```bash
# Edit plugins
vim config/plugin-manifest.lua

# Test locally
make test-manifest

# Package for production
make test-package-manifest

# Interactive debugging
docker run --rm -it -v $(pwd):/workspace airgap-mason-test bash
/workspace/scripts/install-from-manifest.sh

# Push to GitHub
git push
# → GitHub Actions builds automatically
# → Downloads from Actions artifacts tab
```

## File Locations

```
Input:
  config/plugin-manifest.lua

Process:
  scripts/install-from-manifest.sh

Output:
  offline-packages/lazyvim-plugins-manifest.tar.gz
  offline-packages/mason-packages-manifest.tar.gz

Deploy:
  ~/.local/share/nvim/lazy/
  ~/.local/share/nvim/mason/packages/
  ~/.config/nvim/
```

## Next Steps

1. **Try it:** `make test-manifest`
2. **Customize:** Edit `config/plugin-manifest.lua`
3. **Package:** `make test-package-manifest`
4. **Deploy:** Extract tarballs on air-gap machine
5. **Iterate:** Repeat as needed

## Documentation Index

| Document | Purpose | Audience |
|----------|---------|----------|
| `QUICK-START-DRY.md` | 2-min quick start | Everyone |
| `DRY-WORKFLOW.md` | Complete guide | Users |
| `ARCHITECTURE.md` | System design | Developers |
| `ADDING-PLUGINS-AND-LSPS.md` | Plugin details | Customizers |
| `test/SIMPLE.md` | Legacy approach | Reference |
| `test/COMMANDS.md` | Command reference | Power users |
| `test/TESTING.md` | Testing details | Developers |

## Success Metrics

✅ **DRY:** One file controls everything
✅ **Easy:** 5 seconds to add a plugin
✅ **Testable:** Works in Docker
✅ **Automatable:** Works in GitHub Actions
✅ **Reusable:** Same code everywhere
✅ **Documented:** Multiple guides available

## Philosophy

> "Make the right thing easy and the wrong thing hard."

By having a single source of truth:
- Editing one file is easy
- Keeping files in sync is impossible to forget
- Testing locally is straightforward
- Deploying is predictable
- Collaborating is simple

## The DRY Promise

**Edit `config/plugin-manifest.lua` once.**
**Everything else follows automatically.**

That's DRY.
