# GNU Stow Configuration Handling

GNU Stow is optional. When it is installed on the target machine, the installer uses it for symlink-based configuration management. Otherwise, it copies each configuration package into the target home directory.

The direct-copy path is the supported default for air-gapped machines with no Stow package. It lets installation complete without downloading any additional dependency, but subsequent changes are ordinary copied files rather than symlinks back to the kit directory.

To use Stow after installation, install it through your operating system's approved package source, then run it from `config/` as documented in the README.
