# Changes Made to Air-Gap Dev Kit

## Summary

This document outlines the improvements made to address installation flexibility and dotfile management issues.

## 1. Installation Location Flexibility ✅

### Problem
- Installer assumed sudo access and defaulted to `/usr/local/bin`
- No clear upfront choice for users without root access
- Prompt happened mid-installation, not at startup

### Solution
- **Added upfront installation location prompt** at the beginning of `install.sh`
- Two clear options presented:
  1. **System-wide** (`/usr/local/bin`) - Requires sudo, available to all users
  2. **User-local** (`~/.local/bin`) - No sudo needed, only for current user
- Changed default user-local path from `~/bin` to `~/.local/bin` (more standard)
- Improved logic to handle:
  - Already running as root
  - Passwordless sudo available
  - Sudo authentication failure (automatic fallback to user-local)
- Better user feedback with ✓ and ✗ symbols

### Files Modified
- `install.sh` (lines 72-148)

## 2. Dotfile Handling with GNU Stow 🔧

### Problem
- **Current directory structure is NOT Stow-compatible**
- Structure was:
  ```
  config/
  ├── .config/nvim/      # ✗ Wrong - dotfiles at wrong level
  └── .tmux.conf         # ✗ Wrong - should be in package
  ```
- Stow expects packages as subdirectories, each containing the directory structure relative to `$HOME`
- Fallback copy logic had issues with dotfile iteration

### Solution

#### A. Updated `install.sh` Config Installation (lines 525-600)
- **Complete rewrite** of config installation section
- Proper Stow package detection and installation
- Conflict detection with automatic backup
- Improved fallback for when Stow is not available
- Better error handling and user feedback

#### B. Created Helper Script
- `restructure-config-for-stow.sh` - Automatically restructures config directory
- Converts current structure to proper Stow format:
  ```
  config/
  ├── nvim/              # Package name
  │   └── .config/nvim/  # Structure relative to $HOME
  ├── tmux/              # Package name
  │   └── .tmux.conf
  └── starship/          # Package name
      └── .config/starship.toml
  ```

#### C. Created Documentation
- `config/README.md` - Comprehensive guide on:
  - How GNU Stow works
  - Correct directory structure
  - How to add new configurations
  - Testing and troubleshooting
  - Best practices

### Files Created
- `restructure-config-for-stow.sh` - Restructuring helper script
- `config/README.md` - Stow documentation

### Files Modified
- `install.sh` - Config installation logic completely rewritten

## 3. Documentation Updates 📚

### Updated README.md
- Installation steps now mention location prompt
- Directory structure shows both system-wide and user-local paths
- Requirements clarify Stow is optional with automatic fallback
- Expanded troubleshooting section with:
  - User-local install PATH issues
  - Permission problems
  - No sudo access scenarios
  - Stow conflicts
  - Config structure issues

### Files Modified
- `README.md` - Multiple sections updated

## 4. PATH Handling Improvements

### Changes
- Updated shell configuration section to handle both `~/.local/bin` and `~/bin`
- Proper detection of installation location
- Correct PATH export statements for bash/zsh/fish
- Only adds PATH configuration if user-local install

### Files Modified
- `install.sh` (lines 774-789, 586-601)

## Action Items for You

### 1. Restructure Config Directory (REQUIRED)

**Current structure is broken for Stow!** You need to fix it:

```bash
# Option A: Use the helper script
./restructure-config-for-stow.sh

# Review the new structure
ls -R config-new/

# If it looks good, apply it
rm -rf config/
mv config-new config

# Commit the changes
git add config/
git commit -m "Restructure config for GNU Stow compatibility"
```

**Option B: Manual restructuring** (see `config/README.md`)

### 2. Test the Installation

Test both installation modes:

```bash
# Test user-local install (no sudo)
./install.sh
# Choose option 2

# Test system-wide install (with sudo)
./install.sh
# Choose option 1
```

### 3. Update GitHub Actions (if needed)

The workflow should still work, but verify:
- `config/.config/nvim/` path is used in line 49 of `.github/workflows/update-binaries.yml`
- After restructuring, this should become `config/nvim/.config/nvim/`

Update line 49:
```yaml
# OLD
cp -r $GITHUB_WORKSPACE/config/.config/nvim/* ~/.config/nvim/

# NEW (after restructuring)
cp -r $GITHUB_WORKSPACE/config/nvim/.config/nvim/* ~/.config/nvim/
```

### 4. Test Stow Locally

Before committing, test that Stow works:

```bash
# After restructuring
cd config

# Test with dry run
stow -n -v -t ~ nvim

# If no errors, actually stow
stow -t ~ nvim

# Verify symlinks
ls -la ~/.config/nvim
```

### 5. Update CLAUDE.md (Optional)

Consider updating the developer guide with:
- New installation location options
- Stow structure requirements
- Testing procedures

## Benefits

1. **No Root Required**: Users without sudo can now easily install to `~/.local/bin`
2. **Clear Choices**: Upfront prompt makes installation intent clear
3. **Proper Dotfile Management**: Stow structure allows proper symlink management
4. **Better Fallback**: Direct copy works correctly when Stow unavailable
5. **Improved UX**: Better feedback, error handling, and documentation

## Compatibility

- ✅ Backward compatible with existing installations
- ✅ Works with or without GNU Stow
- ✅ Handles both macOS and Linux
- ✅ Supports both root and non-root users
- ⚠️ **Config directory needs restructuring** (one-time change)

## Testing Checklist

- [ ] Restructure config directory
- [ ] Test user-local install (option 2)
- [ ] Test system-wide install (option 1)
- [ ] Test with Stow available
- [ ] Test without Stow (fallback)
- [ ] Test on Linux
- [ ] Test on macOS
- [ ] Verify GitHub Actions still works
- [ ] Update workflow if needed
- [ ] Test plugin bundling still works

## Questions?

See the new documentation:
- `config/README.md` - Stow structure guide
- `README.md` - Updated troubleshooting
- Run `./restructure-config-for-stow.sh --help` (if implemented)
