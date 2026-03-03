# Quick Start: Applying the Fixes

## TL;DR - What You Need to Do

Your config directory structure is **broken for GNU Stow**. Here's how to fix it:

## Step 1: Restructure Config Directory (5 minutes)

```bash
# Run the helper script
./restructure-config-for-stow.sh

# Review what it created
tree config-new/  # or: ls -R config-new/

# If it looks good, apply the changes
rm -rf config/
mv config-new config

# Commit the fix
git add config/
git commit -m "Fix: Restructure config for GNU Stow compatibility"
```

## Step 2: Update GitHub Actions Workflow (2 minutes)

Edit `.github/workflows/update-binaries.yml` line 49:

**Change from:**
```yaml
cp -r $GITHUB_WORKSPACE/config/.config/nvim/* ~/.config/nvim/
```

**Change to:**
```yaml
cp -r $GITHUB_WORKSPACE/config/nvim/.config/nvim/* ~/.config/nvim/
```

Commit:
```bash
git add .github/workflows/update-binaries.yml
git commit -m "Fix: Update workflow for new config structure"
```

## Step 3: Test Locally (5 minutes)

```bash
# Test the installer
./install.sh

# When prompted, choose:
# - Option 1 if you have sudo (system-wide install)
# - Option 2 if no sudo (user-local install)

# Verify binaries are accessible
which nvim
which tmux
which fzf

# If user-local install, add to PATH:
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

## Step 4: Push and Trigger Build (2 minutes)

```bash
# Push all changes
git push

# Go to GitHub Actions and manually trigger a build
# Or wait for the next scheduled build
```

## What Changed?

### 1. Installation Location Prompt ✅
- Installer now asks upfront: system-wide or user-local
- No more assuming sudo access
- Better for air-gapped environments without root

### 2. Dotfile Structure Fixed 🔧
- **Old (broken):**
  ```
  config/.config/nvim/
  config/.tmux.conf
  ```
- **New (correct):**
  ```
  config/nvim/.config/nvim/
  config/tmux/.tmux.conf
  ```

### 3. Better Stow Handling
- Automatic conflict detection and backup
- Proper fallback when Stow not available
- Each config is now a separate "package"

## Verification

After restructuring, your config should look like:

```
config/
├── README.md          # Documentation
├── nvim/              # Package: Neovim
│   └── .config/
│       └── nvim/
│           ├── init.lua
│           └── lua/
├── tmux/              # Package: tmux
│   └── .tmux.conf
└── starship/          # Package: Starship
    └── .config/
        └── starship.toml
```

Test Stow:
```bash
cd config
stow -n -v -t ~ nvim  # Dry run
stow -t ~ nvim        # Actually stow
ls -la ~/.config/nvim # Should show symlinks
```

## Troubleshooting

**"No such file or directory" when running restructure script:**
```bash
chmod +x restructure-config-for-stow.sh
./restructure-config-for-stow.sh
```

**Stow conflicts after restructuring:**
```bash
# Backup existing configs
mv ~/.config/nvim ~/.config/nvim.backup
mv ~/.tmux.conf ~/.tmux.conf.backup

# Try stowing again
cd config && stow -t ~ */
```

**GitHub Actions fails after changes:**
- Check the workflow file path (line 49)
- Verify config/nvim/.config/nvim/ exists
- Check Actions logs for specific error

## Need Help?

- Read `config/README.md` for detailed Stow documentation
- Read `CHANGES.md` for full explanation of changes
- Check `README.md` troubleshooting section
- Review the updated `install.sh` comments

## Summary

1. ✅ Run `./restructure-config-for-stow.sh`
2. ✅ Update `.github/workflows/update-binaries.yml` line 49
3. ✅ Test locally with `./install.sh`
4. ✅ Commit and push
5. ✅ Done!

The installer now works in restricted environments without root access, and your dotfiles are properly managed with GNU Stow.
