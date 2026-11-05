# Test Directory - LazyVim Plugin Packaging

This directory contains everything needed to test and package LazyVim plugins for air-gap deployment.

## GUI desktop launch check

GitHub Actions runs `scripts/test-desktop-launch.sh` from this directory in
the **Test GUI desktop launch** job after the Linux archive is built. It uses
Xvfb, a D-Bus session, and Mesa software rendering on an Ubuntu runner.

The check installs the real archive into a disposable home with spaces in its
path and validates both desktop entries. `gtk-launch` must find and launch the
registered menu item by application ID; `gio launch` opens the desktop shortcut
independently. Each launch must produce a visible WezTerm window and a terminal
pane. A broken `Exec` must fail. Uninstall must remove both registered files.

The same job checks internal Neovim registers without a clipboard provider, then
seeds an X11 CLIPBOARD selection and sends a real middle-click into Neovim inside
WezTerm. The editor cannot find desktop clipboard tools on its PATH; the test
requires the pasted text in its buffer and saves a screenshot.
The job also runs `scripts/test-tmux-clipboard.py` with the installed tmux and
WezTerm binaries and the archive's configurations. Real mouse drags verify tmux
copy mode with neighboring panes, and real middle-clicks must paste CLIPBOARD
even when PRIMARY deliberately contains different text. Raw OSC 52 and tmux DCS
passthrough writes are tested separately.

The same harness accepts `--kitty /path/to/kitty/bin/kitty` to exercise the
portable Kitty bundle with `config/kitty/.config/kitty/kitty.conf`. The bundle
must remain intact, including its libraries and resources. Both terminal paths
check tmux selection with adjacent panes and application OSC 52 writes. The
Kitty path additionally checks native terminal selection. Middle-click must work without modifier keys even
when an application captures the mouse; keyboard shortcuts are supplementary.
These are X11 checks; Wayland and the target Debian/Red Hat desktop still need
separate acceptance tests.

A checksum-pinned OpenCode 2.1.2 binary is downloaded only as a test fixture;
it is not bundled or installed by the kit. The test selects text in OpenCode's
prompt inside tmux with its native mouse handling, checks the external clipboard,
clears the prompt, and middle-clicks to paste it back. OpenCode cannot find
desktop clipboard utilities on its PATH. No prompt is submitted or model
provider required. Set `AIRGAP_TEST_OPENCODE` to this binary when running the
desktop-launch script yourself. Python is used only by the GUI test harness,
not required by the deployed clipboard configuration.

It verifies `vim-empty` bypasses a broken user configuration and environment
initialization, skips plugins, and is removed during uninstall.

The `desktop-launch-evidence` artifact contains screenshots and diagnostic
logs, including failed launches. This verifies application launching through
the desktop-entry format; it does not test GNOME/KDE icon visibility, launcher
trust prompts, Wayland, or physical GPU drivers.

## 📚 Documentation

| File | Purpose |
|------|---------|
| **../docs/QUICK-START-DRY.md** | ⭐ Start here! DRY workflow (recommended) |
| **../docs/DRY-WORKFLOW.md** | Complete DRY guide (single source of truth) |
| **SIMPLE.md** | Simple 3-command approach (legacy) |
| **COMMANDS.md** | Copy-paste command reference |
| **TESTING.md** | Detailed testing documentation |
| **../docs/ADDING-PLUGINS-AND-LSPS.md** | How to add plugins and LSP servers |

## 🚀 Quick Start

### DRY Workflow (Recommended)

```bash
# 1. Edit the manifest
vim config/plugin-manifest.lua

# 2. Test locally
make test-manifest

# 3. Package for production
make test-package-manifest
```

### Legacy Workflow

```bash
# Test plugin installation
make test

# Package for air-gap
make test-package

# Interactive testing
make test-interactive
```

## 📁 Files

- `test-config-based.sh` - Main test script (installs LazyVim plugins)
- `test-mason.sh` - Mason LSP installation test (multiple modes)
- `test-mason.Dockerfile` - Docker environment with Neovim + dependencies
- `scripts/` - Helper scripts for test setup
- `lib/` - Common test utilities

## 🎯 What Gets Packaged?

### LazyVim Plugins
- **Location:** `~/.local/share/nvim/lazy/`
- **Install:** `nvim --headless "+Lazy! sync" +qa`
- **Package:** Created by `make test-package`
- **Output:** `offline-packages/lazyvim-plugins.tar.gz`

### Mason Packages (LSP/Formatters)
- **Location:** `~/.local/share/nvim/mason/packages/`
- **Install:** `nvim --headless "+MasonInstall <package>" +qa`
- **Package:** Manual: `tar -czf mason-packages.tar.gz -C ~/.local/share/nvim/mason packages/`
- **TODO:** Add `make package-mason` target

## 🔧 Common Tasks

### Test Plugin Installation
```bash
make test
# Or manually:
docker run --rm -v $(pwd):/workspace airgap-mason-test bash /workspace/test/test-config-based.sh
```

### Package Plugins
```bash
make test-package
# Creates: offline-packages/lazyvim-plugins.tar.gz
```

### Debug Interactively
```bash
make test-interactive
# Inside container, see COMMANDS.md for what to run
```

### Test Mason Packages
```bash
# Single plugin mode
docker run --rm -v $(pwd):/workspace airgap-mason-test bash /workspace/test/test-mason.sh single lua-language-server

# GitHub workflow mode
make test-github
```

## 🐳 Docker Image

The `test-mason.Dockerfile` creates an Ubuntu 24.04 image with:
- Neovim v0.11.2 (built from source)
- Git, curl, wget
- ripgrep, fd, fzf
- Node.js, npm
- Build tools (cmake, ninja, etc.)
- Lazygit
- Test scripts in `/opt/test-scripts/`

**Why build from source?** System Neovim doesn't have the latest features LazyVim needs.

**Why not use static binary?** Testing needs full Neovim with runtime files and Lua modules.

## 🏗️ Build & Test Flow

```
1. Edit config files
   ↓
2. Run make test (installs plugins in Docker)
   ↓
3. Run make test-package (extracts plugins to tarball)
   ↓
4. Transfer tarball to air-gap machine
   ↓
5. Extract and use!
```

## 📝 Adding New Plugins

See `docs/ADDING-PLUGINS-AND-LSPS.md` for details.

**Quick version:**
1. Edit `config/nvim/.config/nvim/lua/plugins/my-plugins.lua`
2. Add: `{ "author/plugin-name" }`
3. Run: `make test-package`
4. Done!

## 🔍 Troubleshooting

### Docker build fails?
```bash
# Force rebuild without cache
make test-rebuild
```

### Plugins not installing?
```bash
# Check Neovim version
docker run --rm airgap-mason-test nvim --version

# Check logs
docker run --rm -it airgap-mason-test bash
cat ~/.local/state/nvim/lazy.log
```

### Need to test manually?
```bash
make test-interactive
# Then follow commands in COMMANDS.md
```

## 🎓 Key Concepts

### Two Separate Systems

1. **LazyVim Plugins** (lazy.nvim)
   - Editor features, UI, utilities
   - Managed by `lazy.nvim`
   - Config: `lua/plugins/*.lua`
   - Syntax: `{ "author/repo" }`

2. **Mason Packages** (Mason)
   - LSP servers, formatters, linters
   - Managed by Mason
   - Config: Same files, different section
   - Syntax: `ensure_installed = { "package-name" }`

### Air-Gap Mode

Your config has:
```lua
install = {
  missing = false,  -- Don't download plugins
}
```

This tells LazyVim to use pre-installed plugins only.

## 🚧 TODO

- [ ] Add `make package-mason` target
- [ ] Automate Mason package bundling
- [ ] Add version pinning for plugins
- [ ] Create GitHub Action for auto-packaging
- [ ] Add verification script for air-gap machine

## 📖 Further Reading

- LazyVim docs: https://www.lazyvim.org
- lazy.nvim docs: https://lazy.folke.io
- Mason docs: https://github.com/mason-org/mason.nvim
- Mason package list: https://mason-registry.dev/registry/list

The **Offline editor** jobs run four independent suites (`core`, `languages`,
`formatting`, and `plugins`) with `fail-fast: false`. Each runs
`bash test/scripts/test-editor-health.sh <archive>` in a Linux network namespace
without network access. It installs the release archive into a disposable home,
loads every manifest parser and its highlighting queries, parses valid and
invalid Lua, starts highlighting, runs the bundled Tree-sitter CLI, and checks
internal yank behavior. Every suite also saves a file, reopens it in a second
Neovim process, and verifies the plugin lockfile stayed unchanged.

The additional behavior checks in `scripts/editor-integration.lua` cover:

- Initialization and attachment of all nine manifest language servers. Adding
  a server to the manifest requires adding a fixture; missing coverage fails.
- Real Lua LSP completion and go-to-definition, plus errors appearing on invalid
  code and clearing after repair.
- Formatting Lua, JSON, YAML, JavaScript, TypeScript, and shell buffers through the installed Conform
  configuration with StyLua, Prettier, and shfmt, then checking saved content.
- ShellCheck diagnostics and the eslint_d launcher.
- File discovery, text search, fuzzy filtering, Snacks file/grep pickers and
  explorer, completion's Lua fuzzy matcher, and normal-mode yank/paste.

The offline editor configuration connects bundled Prettier to Conform for its
supported web/document filetypes and selects Blink's Lua matcher explicitly.
Completion therefore works without downloading a native library on first use.

The language suite uses the runner's preinstalled Go and Rust toolchains for
workspace support. Those toolchains are not bundled in the kit. Node-based
Mason tools use the kit's bundled Node runtime. Go module downloads, automatic
Go toolchain downloads, and Cargo network access are disabled in the tests.
No language fixture requires third-party dependencies.

The `editor-health-evidence-<suite>` artifacts retain the full health buffer,
startup and integration logs, per-case JSON results, and the LSP log, including
on failures. Optional provider and headless UI warnings are informational;
required editor behavior fails the job. The tag-triggered release workflow
runs all suites against its own archive before publishing; its evidence is
saved as `release-editor-health-<tag>`.

To reproduce all checks on a Linux host with Go and Rust installed:

```bash
sudo env PATH="$PATH" RUSTUP_HOME="$HOME/.rustup" CARGO_HOME="$HOME/.cargo" \
  AIRGAP_HEALTH_RESULTS=/tmp/editor-health-results \
  unshare --net bash test/scripts/test-editor-health.sh airgap-dev-kit-linux-x86_64.tar.gz
```

Set `AIRGAP_EDITOR_SUITE` to a suite name to run that group with the core checks.

## Minimal systems, projects, and signed upgrades

The **Minimal offline Linux** jobs use Debian 12 slim and Ubuntu 22.04 images.
Only Git and certificate packages are added before the container starts with
`--network none`. The editor installs as an unprivileged user. Preflight rejects
host Node/npm, Python, Go, Rust, C compilers, curl, and wget. The core editor,
formatter, and picker tests then run against the actual archive. Bundled Node
must supply the JavaScript tools; no host module or editor caches are mounted.
Evidence is retained as `minimal-editor-<index>`.

```bash
AIRGAP_MINIMAL_IMAGE=debian:12-slim \
  bash test/scripts/test-minimal-editor.sh airgap-dev-kit-linux-x86_64.tar.gz
```

The **Offline editor (projects)** job adds dependency-free Lua, Bash, Python,
Go, Rust, JavaScript, and TypeScript projects. It executes their assertions,
tests project-symbol completion and definition lookup, and checks that language
errors appear and clear after repair. JSON/YAML document symbols and syntax
diagnostics and Markdown links are tested through their language servers.
Go/Cargo build and module caches start empty; package downloads and automatic
Go toolchain downloads remain disabled. This suite requires preinstalled Go,
Rust (including rust-src/rustfmt and a system linker), and Python. TypeScript's
compiler and Node come from the kit. These host toolchains are test prerequisites,
not additional kit payloads. The release workflow runs these checks too.

The **Signed offline upgrade and rollback** job downloads the fixed published
v2.7.0 and v2.7.1 fixtures while connected, then uses the current source-built
updater with networking disabled as a normal user. The production public key
must validate both releases. Personal editor data, terminal configurations,
shell settings, an unrelated executable, and project files are checksummed
across upgrade, rollback, and uninstall. Shell integration must stay functional,
occur once, and disappear on uninstall. Logs are retained as
`signed-upgrade-evidence`; no test-only signing key replaces release trust.

Physical desktop acceptance remains separate: transfer the verified archive to
the actual Debian/Red Hat machine, extract it on a Linux filesystem, run
`./airgap doctor --verify`, install as your normal user, and test fonts, desktop
launching, selection/copy/middle-click paste, and SSH/tmux on the actual X11 or
Wayland session. Record the kit version, distribution, session type, and results.
Xvfb and container tests do not establish physical GPU or Wayland acceptance.

The GUI launch job also opens the full kit LazyVim profile in a real WezTerm
terminal UI, checks Snacks input/picker/dashboard registration after startup,
and captures `editor-ui-checkhealth.txt`. This separates actual UI failures from
warnings caused by running UI health checks in headless Neovim. The offline
editor jobs verify language servers and formatting separately from the desktop UI.
