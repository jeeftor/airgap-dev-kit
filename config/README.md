# Configuration Directory Structure

This directory contains dotfiles and configuration files that will be installed to your home directory.

## GNU Stow Compatibility

This project uses [GNU Stow](https://www.gnu.org/software/stow/) for managing dotfiles via symlinks. If Stow is not available, the installer will fall back to copying files directly.

### Directory Structure

Each subdirectory in `config/` represents a **package** that can be installed independently. The directory structure within each package mirrors the structure relative to your home directory (`$HOME`).

**Example Structure:**
```
config/
├── nvim/              # Package: Neovim configuration
│   └── .config/
│       └── nvim/
│           ├── init.lua
│           └── lua/
├── tmux/              # Package: tmux configuration
│   └── .tmux.conf
├── starship/          # Package: Starship prompt
│   └── .config/
│       └── starship.toml
└── bash/              # Package: Bash configuration
    └── .bashrc
```

### How Stow Works

When you run `stow -t ~ nvim` from the `config/` directory:
- Stow creates symlinks in `$HOME` that point to files in `config/nvim/`
- `config/nvim/.config/nvim/init.lua` → `~/.config/nvim/init.lua`
- This allows you to manage your dotfiles in a git repository while keeping them in their expected locations

### Current Structure

```
config/
├── nvim/              # Package: Neovim configuration
│   └── .config/nvim/
├── tmux/              # Package: tmux configuration
│   └── .tmux.conf
├── starship/          # Package: Starship prompt
│   └── .config/starship.toml
└── plugin-manifest.lua  # Build-time manifest (not a Stow package)
```

## Adding New Configurations

To add a new configuration file:

1. Create a package directory: `mkdir -p config/myapp`
2. Add your dotfile with the correct path structure:
   - For `~/.myapprc`: `config/myapp/.myapprc`
   - For `~/.config/myapp/config.toml`: `config/myapp/.config/myapp/config.toml`
3. Commit to git: `git add config/myapp && git commit -m "Add myapp config"`

## Testing Locally

Test your Stow configuration before committing:

```bash
# Install a single package
cd config
stow -t ~ nvim

# Install all packages
cd config
stow -t ~ */

# Remove a package (unstow)
cd config
stow -D -t ~ nvim

# Dry run (see what would happen)
cd config
stow -n -v -t ~ nvim
```

## GitHub Actions Integration

When you push changes to `config/`, GitHub Actions will:
1. Use your Neovim config to install plugins
2. Bundle everything into the release package
3. The installer will use Stow (if available) to symlink your configs

## Troubleshooting

### Stow Conflicts

If Stow reports conflicts (files already exist):

```bash
# Backup existing files
mv ~/.config/nvim ~/.config/nvim.backup

# Try stowing again
cd config && stow -t ~ nvim
```

### No Stow Available

The installer will automatically fall back to copying files if Stow is not installed. However, you won't get the benefits of symlink management.

To install Stow:
- **Debian/Ubuntu**: `apt-get install stow`
- **RHEL/Fedora**: `dnf install stow`
- **Arch**: `pacman -S stow`
- **macOS**: `brew install stow`

## Best Practices

1. **Keep packages small**: One package per application/tool
2. **Use meaningful names**: Package names should match the application (nvim, tmux, bash, etc.)
3. **Test before committing**: Always test with `stow -n -v` first
4. **Document custom configs**: Add comments explaining non-obvious settings
5. **Version control**: Commit your configs regularly

## References

- [GNU Stow Manual](https://www.gnu.org/software/stow/manual/stow.html)
- [Managing Dotfiles with GNU Stow](https://brandon.invergo.net/news/2012-05-26-using-gnu-stow-to-manage-your-dotfiles.html)
- [Stow Tutorial](https://alexpearce.me/2016/02/managing-dotfiles-with-stow/)
