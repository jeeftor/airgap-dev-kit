# Local Testing with Docker

Test Mason LSP and LazyVim installations locally without pushing to GitHub.

## Quick Start

### Test Mason LSP Installation

```bash
# Build and run automated test
./test-mason-docker.sh

# Or run interactively to debug
docker build -f test-mason.Dockerfile -t airgap-mason-test .
docker run --rm -it -v $(pwd):/workspace airgap-mason-test bash

# Inside container:
bash /workspace/test-mason.sh
```

### Test LazyVim Plugin Installation

```bash
docker build -f test-mason.Dockerfile -t airgap-mason-test .
docker run --rm -it -v $(pwd):/workspace airgap-mason-test bash /workspace/test-lazyvim.sh
```

## Test Scripts

### `test-mason.sh`
Tests vanilla Neovim + Mason LSP server installation:
- Creates minimal Mason config
- Installs Mason plugin via lazy.nvim
- Tests Mason registry loading
- Attempts package discovery and installation
- Shows which packages are found/missing

**Use this to debug:**
- Mason registry loading issues
- Package name mismatches
- Async installation timing problems

### `test-lazyvim.sh`
Tests your actual LazyVim config:
- Copies config from `config/nvim/.config/nvim/`
- Runs `Lazy! sync` like GitHub Actions
- Shows installed plugins
- Checks if Mason packages were installed

**Use this to verify:**
- LazyVim plugin installation works
- Your config loads correctly
- Mason packages from `airgap-lsp.lua` are installed

## Interactive Debugging

```bash
# Start container with shell
docker run --rm -it -v $(pwd):/workspace airgap-mason-test bash

# Inside container, you can:
nvim --version                          # Verify Neovim
bash /workspace/test-mason.sh           # Run Mason test
bash /workspace/test-lazyvim.sh         # Run LazyVim test

# Or manually test commands:
NVIM_APPNAME=nvim-test nvim --headless "+Lazy! sync" +qa
ls -la ~/.local/share/nvim-test/

# Check Mason registry manually:
nvim --headless -c "lua print(vim.inspect(require('mason-registry').get_all_package_names()))" +qa
```

## Iterate Faster

Instead of pushing to GitHub and waiting for Actions:

1. **Edit test scripts** - Modify `test-mason.sh` or `test-lazyvim.sh`
2. **Run in Docker** - `./test-mason-docker.sh`
3. **See results immediately** - No GitHub Actions delay
4. **Debug interactively** - Drop into container shell to experiment

## Common Issues to Debug

### Mason Registry Not Loading
**Symptom:** All packages show "Not found"
**Test:** Run `test-mason.sh` and check "Testing Mason Registry" section
**Fix ideas:**
- Increase wait time after `registry.refresh()`
- Check if registry needs `:on_ready()` callback
- Verify network access in container

### Async Installation Not Completing
**Symptom:** Installation starts but doesn't finish
**Test:** Look for "Waiting..." messages in `test-mason.sh`
**Fix ideas:**
- Increase timeout
- Use different Mason API methods
- Check if Neovim exits before async completes

### Package Name Mismatches
**Symptom:** "X is not a valid package"
**Test:** Check package discovery list in test output
**Fix ideas:**
- Verify correct Mason package names
- Check if package was renamed/moved
- Browse Mason registry: https://github.com/mason-org/mason-registry

## Files

- `test-mason.Dockerfile` - Docker image with static Neovim
- `test-mason.sh` - Test Mason LSP installation
- `test-lazyvim.sh` - Test LazyVim plugin installation
- `test-mason-docker.sh` - Wrapper to build and run tests
- `TESTING.md` - This file
