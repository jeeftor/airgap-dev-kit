# Installation Tracking & Undo System

The Air-Gap Dev Kit now includes a comprehensive installation tracking system that records everything installed, allowing for clean uninstallation and recovery.

## Overview

When you run `./install.sh`, it creates a log file at `~/.airgap-dev-kit-install.log` that tracks:
- Every binary installed
- Every configuration file copied or symlinked
- Every Stow package installed
- Every shell configuration added
- Backup locations for overwritten files

## Installation Log Format

The log file uses a pipe-delimited format:

```
TYPE|PATH|BACKUP_PATH|TIMESTAMP
```

### Entry Types

- **METADATA** - Installation metadata (OS, BIN_DIR, USE_SUDO)
- **BINARY** - Executable binaries
- **CONFIG** - Configuration files
- **SYMLINK** - Symbolic links
- **DIRECTORY** - Directories created
- **STOW_PACKAGE** - GNU Stow packages
- **SHELL_CONFIG** - Shell RC file modifications

### Example Log

```
# Air-Gap Dev Kit Installation Log
# Generated: Mon Nov 11 05:04:23 PST 2025
METADATA|OS=linux|||
METADATA|BIN_DIR=/home/user/.local/bin|||
METADATA|USE_SUDO=|||
DIRECTORY|/home/user/.local/bin|||
BINARY|/home/user/.local/bin/gum|||20251111-050425
BINARY|/home/user/.local/bin/fzf|||20251111-050426
BINARY|/home/user/.local/bin/nvim|/home/user/.local/bin/nvim.backup-20251111-050427|20251111-050427
SYMLINK|/home/user/.local/bin/nvim|/home/user/nvim-linux-x86_64/bin/nvim||
DIRECTORY|/home/user/nvim-linux-x86_64|||
DIRECTORY|/home/user/.local/share/nvim/lazy|||
STOW_PACKAGE|nvim|||
STOW_PACKAGE|tmux|||
CONFIG|/home/user/.config/nvim|/home/user/.config/nvim.backup-20251111-050428|
CONFIG|/home/user/.tmux.conf|||
SHELL_CONFIG|/home/user/.bashrc||PATH configuration|
SHELL_CONFIG|/home/user/.bashrc||Starship prompt|
# Installation completed at Mon Nov 11 05:15:42 PST 2025
```

## Using the Uninstaller

### Smart Uninstall (with log)

If the installation log exists, `uninstall.sh` uses it for precise removal:

```bash
./uninstall.sh
```

The uninstaller will:
1. ✅ Read the installation log
2. ✅ Show exactly what will be removed
3. ✅ Remove only what was installed by this kit
4. ✅ Preserve backups created during installation
5. ✅ Unstow Stow packages properly
6. ✅ Clean shell configurations
7. ✅ Offer to remove the log file itself

### Fallback Uninstall (without log)

If no log exists, the uninstaller falls back to:
- Searching common installation locations
- Using hardcoded list of binaries
- Prompting for each removal

## Manual Operations

### View Installation Log

```bash
cat ~/.airgap-dev-kit-install.log
```

### List Installed Binaries

```bash
grep "^BINARY|" ~/.airgap-dev-kit-install.log | cut -d'|' -f2
```

### List Backups

```bash
grep "^.*|.*|.*backup.*|" ~/.airgap-dev-kit-install.log
```

### Find Stow Packages

```bash
grep "^STOW_PACKAGE|" ~/.airgap-dev-kit-install.log | cut -d'|' -f2
```

### Restore a Backup

If a file was backed up during installation:

```bash
# Find the backup
grep "CONFIG|/home/user/.tmux.conf" ~/.airgap-dev-kit-install.log

# Output shows: CONFIG|/home/user/.tmux.conf|/home/user/.tmux.conf.backup-20251111-050428|

# Restore it
mv /home/user/.tmux.conf.backup-20251111-050428 /home/user/.tmux.conf
```

## Partial Uninstall

You can manually remove specific components using the log:

### Remove Only Binaries

```bash
while IFS='|' read -r type path backup timestamp; do
  if [[ "$type" == "BINARY" && -f "$path" ]]; then
    rm -f "$path"
    echo "Removed: $path"
  fi
done < <(grep "^BINARY|" ~/.airgap-dev-kit-install.log)
```

### Remove Only Configs

```bash
while IFS='|' read -r type path backup timestamp; do
  if [[ "$type" == "CONFIG" && -e "$path" ]]; then
    rm -rf "$path"
    echo "Removed: $path"
  fi
done < <(grep "^CONFIG|" ~/.airgap-dev-kit-install.log)
```

### Unstow Specific Package

```bash
cd config
stow -D -t ~ nvim
```

## Reinstallation

The installation log is overwritten on each install, so:

1. **First install** - Creates new log
2. **Reinstall** - Overwrites log with new data
3. **Uninstall** - Can remove log or keep it

If you want to preserve the old log:

```bash
cp ~/.airgap-dev-kit-install.log ~/.airgap-dev-kit-install.log.backup
./install.sh
```

## Backup Strategy

The installer automatically creates backups when:
- Overwriting existing binaries
- Replacing configuration files
- Stow detects conflicts

Backups are named with timestamps:
```
original-file.backup-20251111-050428
```

These backups are **tracked in the log** and preserved during uninstallation.

## Troubleshooting

### Log File Corrupted

If the log is corrupted, the uninstaller will fall back to the hardcoded method:

```bash
# Manually remove the log
rm ~/.airgap-dev-kit-install.log

# Run uninstaller (will use fallback)
./uninstall.sh
```

### Can't Find Backups

List all backups from the log:

```bash
awk -F'|' '$3 != "" {print $3}' ~/.airgap-dev-kit-install.log
```

### Partial Installation Failed

If installation was interrupted, the log shows what was completed:

```bash
# Check if installation completed
tail -1 ~/.airgap-dev-kit-install.log

# If it says "Installation completed", it finished
# Otherwise, it was interrupted
```

You can safely run `./uninstall.sh` to remove partial installations.

## Security Considerations

The installation log contains:
- ✅ File paths (no sensitive data)
- ✅ Timestamps
- ✅ Installation metadata
- ❌ No passwords or credentials
- ❌ No file contents

The log file is stored in your home directory with standard user permissions.

## Advanced: Custom Tracking

If you manually install additional tools, you can add them to the log:

```bash
echo "BINARY|/home/user/.local/bin/mytool|||$(date +%Y%m%d-%H%M%S)" >> ~/.airgap-dev-kit-install.log
```

The uninstaller will then remove them too.

## Comparison to Other Systems

| Feature | Air-Gap Dev Kit | Homebrew | apt/yum | Nix |
|---------|----------------|----------|---------|-----|
| Tracks installations | ✅ | ✅ | ✅ | ✅ |
| Tracks backups | ✅ | ❌ | ❌ | ✅ |
| Works offline | ✅ | ❌ | ❌ | ⚠️ |
| No root required | ✅ | ✅ | ❌ | ✅ |
| Portable | ✅ | ❌ | ❌ | ⚠️ |
| Stow integration | ✅ | ❌ | ❌ | ❌ |

## Future Enhancements

Potential improvements:
- JSON format option
- Rollback to previous installation
- Diff between installations
- Export/import installation profiles
- Verify installation integrity

## See Also

- `install.sh` - Main installer with tracking
- `uninstall.sh` - Smart uninstaller
- `config/README.md` - Stow package documentation
- `CHANGES.md` - Recent changes including tracking system
