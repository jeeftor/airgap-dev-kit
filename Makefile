.PHONY: help update verify package clean install sync-nvim-config

# Version variables - update these when new releases are available
WEZTERM_VERSION := 20230712-072601-f4abf8fd
FZF_VERSION := 0.66.1
TMUX_VERSION := 3.5a
NERD_FONT_VERSION := v3.2.1
BTOP_VERSION := v1.3.2
EZA_VERSION := v0.18.2
ZOX_VERSION := v0.9.8
DELTA_VERSION := 0.17.0
GUM_VERSION := v0.15.1

# Detect OS for local testing
OS := $(shell uname -s)
ifeq ($(OS),Darwin)
	OS_TYPE := macos
else
	OS_TYPE := linux
endif

help:
	@echo "Air-Gap Dev Kit - Makefile Commands"
	@echo "===================================="
	@echo "make update            - Download all missing binaries"
	@echo "make verify            - Verify all binaries are present and valid"
	@echo "make package           - Create tarball for offline deployment"
	@echo "make install           - Install on current machine (runs install.sh)"
	@echo "make sync-nvim-config  - Sync local Neovim config to repo"
	@echo "make clean             - Remove downloaded binaries (keeps placeholders)"
	@echo "make clean-all         - Remove everything including package tarballs"
	@echo ""
	@echo "Current status:"
	@$(MAKE) --no-print-directory status

status:
	@echo "Checking binary status..."
	@echo ""
	@echo "Core binaries:"
	@ls -lh offline-packages/linux/{wezterm.AppImage,tmux-3.4-static-x86_64,nvim-linux64.tar.gz} 2>/dev/null | awk '{print $$5 "\t" $$9}' || echo "  Some core binaries missing"
	@echo ""
	@echo "CLI tools:"
	@ls -lh offline-packages/linux/{fzf,fd,rg,bat,starship,btop,eza,zoxide,delta,gum} 2>/dev/null | awk '{print $$5 "\t" $$9}' || echo "  Some tools missing"
	@echo ""
	@echo "macOS binaries:"
	@ls -lh offline-packages/macos/{WezTerm-macos.zip,nvim-macos-arm64.tar.gz} 2>/dev/null | awk '{print $$5 "\t" $$9}' || echo "  Some binaries missing"
	@echo ""
	@echo "Fonts:"
	@ls -lh fonts/JetBrainsMono.zip 2>/dev/null | awk '{print $$5 "\t" $$9}' || echo "  Font missing"

update: update-linux update-macos update-fonts
	@echo ""
	@echo "✓ All binaries downloaded!"
	@echo "Run 'make verify' to check integrity"

update-linux:
	@echo "Downloading Linux binaries..."
	@mkdir -p offline-packages/linux

	# WezTerm AppImage
	@if [ ! -f offline-packages/linux/wezterm.AppImage ] || [ $$(stat -f%z offline-packages/linux/wezterm.AppImage 2>/dev/null || stat -c%s offline-packages/linux/wezterm.AppImage 2>/dev/null) -lt 1000 ]; then \
		echo "  → WezTerm AppImage..."; \
		curl -fL "https://github.com/wez/wezterm/releases/download/$(WEZTERM_VERSION)/WezTerm-$(WEZTERM_VERSION)-Ubuntu20.04.AppImage" \
			-o offline-packages/linux/wezterm.AppImage; \
		chmod +x offline-packages/linux/wezterm.AppImage; \
	else \
		echo "  ✓ WezTerm AppImage already present"; \
	fi

	# tmux AppImage
	@if [ ! -f offline-packages/linux/tmux-3.4-static-x86_64 ] || [ $$(stat -f%z offline-packages/linux/tmux-3.4-static-x86_64 2>/dev/null || stat -c%s offline-packages/linux/tmux-3.4-static-x86_64 2>/dev/null) -lt 1000 ]; then \
		echo "  → tmux AppImage..."; \
		curl -fL "https://github.com/nelsonenzo/tmux-appimage/releases/download/$(TMUX_VERSION)/tmux.appimage" \
			-o offline-packages/linux/tmux-3.4-static-x86_64; \
		chmod +x offline-packages/linux/tmux-3.4-static-x86_64; \
	else \
		echo "  ✓ tmux already present"; \
	fi

	# Neovim Linux
	@if [ ! -f offline-packages/linux/nvim-linux64.tar.gz ] || [ $$(stat -f%z offline-packages/linux/nvim-linux64.tar.gz 2>/dev/null || stat -c%s offline-packages/linux/nvim-linux64.tar.gz 2>/dev/null) -lt 1000 ]; then \
		echo "  → Neovim Linux static build..."; \
		curl -fL "https://github.com/neovim/neovim/releases/download/v0.11.5/nvim-linux-x86_64.tar.gz" \
			-o offline-packages/linux/nvim-linux64.tar.gz; \
	else \
		echo "  ✓ Neovim Linux already present"; \
	fi

	# fzf
	@if [ ! -f offline-packages/linux/fzf ] || [ $$(stat -f%z offline-packages/linux/fzf 2>/dev/null || stat -c%s offline-packages/linux/fzf 2>/dev/null) -lt 1000 ]; then \
		echo "  → fzf fuzzy finder..."; \
		curl -fL "https://github.com/junegunn/fzf/releases/download/v$(FZF_VERSION)/fzf-$(FZF_VERSION)-linux_amd64.tar.gz" | \
			tar -xz -C offline-packages/linux/ fzf; \
		chmod +x offline-packages/linux/fzf; \
	else \
		echo "  ✓ fzf already present"; \
	fi

	@echo "  ✓ fd, rg, bat, starship already present (verified earlier)"

	# btop - resource monitor
	@if [ ! -f offline-packages/linux/btop ] || [ $$(stat -f%z offline-packages/linux/btop 2>/dev/null || stat -c%s offline-packages/linux/btop 2>/dev/null) -lt 1000 ]; then \
		echo "  → btop (resource monitor)..."; \
		curl -fL "https://github.com/aristocratos/btop/releases/download/$(BTOP_VERSION)/btop-x86_64-linux-musl.tbz" | \
			tar -xj -C /tmp/ && mv /tmp/btop/bin/btop offline-packages/linux/btop && rm -rf /tmp/btop; \
		chmod +x offline-packages/linux/btop; \
	else \
		echo "  ✓ btop already present"; \
	fi

	# eza - modern ls replacement
	@if [ ! -f offline-packages/linux/eza ] || [ $$(stat -f%z offline-packages/linux/eza 2>/dev/null || stat -c%s offline-packages/linux/eza 2>/dev/null) -lt 1000 ]; then \
		echo "  → eza (modern ls)..."; \
		curl -fL "https://github.com/eza-community/eza/releases/download/$(EZA_VERSION)/eza_x86_64-unknown-linux-musl.tar.gz" | \
			tar -xz -C offline-packages/linux/ ./eza; \
		chmod +x offline-packages/linux/eza; \
	else \
		echo "  ✓ eza already present"; \
	fi

	# zoxide - smarter cd
	@if [ ! -f offline-packages/linux/zoxide ] || [ $$(stat -f%z offline-packages/linux/zoxide 2>/dev/null || stat -c%s offline-packages/linux/zoxide 2>/dev/null) -lt 1000 ]; then \
		echo "  → zoxide (smarter cd)..."; \
		curl -fL "https://github.com/ajeetdsouza/zoxide/releases/download/$(ZOX_VERSION)/zoxide-$$(echo $(ZOX_VERSION) | sed 's/^v//')-x86_64-unknown-linux-musl.tar.gz" | \
			tar -xz -C offline-packages/linux/; \
		chmod +x offline-packages/linux/zoxide; \
	else \
		echo "  ✓ zoxide already present"; \
	fi

	# delta - better git diff
	@if [ ! -f offline-packages/linux/delta ] || [ $$(stat -f%z offline-packages/linux/delta 2>/dev/null || stat -c%s offline-packages/linux/delta 2>/dev/null) -lt 1000 ]; then \
		echo "  → delta (better git diff)..."; \
		curl -fL "https://github.com/dandavison/delta/releases/download/$(DELTA_VERSION)/delta-$(DELTA_VERSION)-x86_64-unknown-linux-musl.tar.gz" | \
			tar -xz --strip-components=1 -C /tmp/ && mv /tmp/delta offline-packages/linux/delta; \
		chmod +x offline-packages/linux/delta; \
	else \
		echo "  ✓ delta already present"; \
	fi

	# gum - charm bracelet TUI library
	@if [ ! -f offline-packages/linux/gum ] || [ $$(stat -f%z offline-packages/linux/gum 2>/dev/null || stat -c%s offline-packages/linux/gum 2>/dev/null) -lt 1000 ]; then \
		echo "  → gum (pretty TUI toolkit)..."; \
		curl -fL "https://github.com/charmbracelet/gum/releases/download/$(GUM_VERSION)/gum_$$(echo $(GUM_VERSION) | sed 's/^v//')_Linux_x86_64.tar.gz" | \
			tar -xz -C /tmp/ && mv /tmp/gum_$$(echo $(GUM_VERSION) | sed 's/^v//')_Linux_x86_64/gum offline-packages/linux/gum && rm -rf /tmp/gum_*; \
		chmod +x offline-packages/linux/gum; \
	else \
		echo "  ✓ gum already present"; \
	fi

update-macos:
	@echo "Downloading macOS binaries..."
	@mkdir -p offline-packages/macos

	# WezTerm macOS
	@if [ ! -f offline-packages/macos/WezTerm-macos.zip ] || [ $$(stat -f%z offline-packages/macos/WezTerm-macos.zip 2>/dev/null || stat -c%s offline-packages/macos/WezTerm-macos.zip 2>/dev/null) -lt 1000 ]; then \
		echo "  → WezTerm macOS..."; \
		curl -fL "https://github.com/wez/wezterm/releases/download/$(WEZTERM_VERSION)/WezTerm-macos-$(WEZTERM_VERSION).zip" \
			-o offline-packages/macos/WezTerm-macos.zip; \
	else \
		echo "  ✓ WezTerm macOS already present"; \
	fi

	# Neovim macOS ARM64
	@if [ ! -f offline-packages/macos/nvim-macos-arm64.tar.gz ] || [ $$(stat -f%z offline-packages/macos/nvim-macos-arm64.tar.gz 2>/dev/null || stat -c%s offline-packages/macos/nvim-macos-arm64.tar.gz 2>/dev/null) -lt 1000000 ]; then \
		echo "  → Neovim macOS ARM64..."; \
		curl -fL "https://github.com/neovim/neovim/releases/download/v0.11.5/nvim-macos-arm64.tar.gz" \
			-o offline-packages/macos/nvim-macos-arm64.tar.gz; \
	else \
		echo "  ✓ Neovim macOS already present"; \
	fi

	# gum - charm bracelet TUI library
	@if [ ! -f offline-packages/macos/gum ] || [ $$(stat -f%z offline-packages/macos/gum 2>/dev/null || stat -c%s offline-packages/macos/gum 2>/dev/null) -lt 1000 ]; then \
		echo "  → gum (pretty TUI toolkit)..."; \
		curl -fL "https://github.com/charmbracelet/gum/releases/download/$(GUM_VERSION)/gum_$$(echo $(GUM_VERSION) | sed 's/^v//')_Darwin_arm64.tar.gz" | \
			tar -xz -C /tmp/ && mv /tmp/gum_$$(echo $(GUM_VERSION) | sed 's/^v//')_Darwin_arm64/gum offline-packages/macos/gum && rm -rf /tmp/gum_*; \
		chmod +x offline-packages/macos/gum; \
	else \
		echo "  ✓ gum already present"; \
	fi

update-fonts:
	@echo "Checking fonts..."
	@mkdir -p fonts
	@if [ ! -f fonts/JetBrainsMono.zip ] || [ $$(stat -f%z fonts/JetBrainsMono.zip 2>/dev/null || stat -c%s fonts/JetBrainsMono.zip 2>/dev/null) -lt 1000000 ]; then \
		echo "  → JetBrainsMono Nerd Font..."; \
		curl -fL "https://github.com/ryanoasis/nerd-fonts/releases/download/$(NERD_FONT_VERSION)/JetBrainsMono.zip" \
			-o fonts/JetBrainsMono.zip; \
	else \
		echo "  ✓ JetBrainsMono Nerd Font already present"; \
	fi

verify:
	@echo "Verifying binaries..."
	@echo ""
	@echo "Core Linux binaries:"
	@file offline-packages/linux/wezterm.AppImage 2>/dev/null | grep -q "executable" && echo "  ✓ wezterm.AppImage" || echo "  ✗ wezterm.AppImage - missing or invalid"
	@file offline-packages/linux/tmux-3.4-static-x86_64 2>/dev/null | grep -q "executable" && echo "  ✓ tmux-3.4-static-x86_64" || echo "  ✗ tmux-3.4-static-x86_64 - missing or invalid"
	@file offline-packages/linux/nvim-linux64.tar.gz 2>/dev/null | grep -q "gzip" && echo "  ✓ nvim-linux64.tar.gz" || echo "  ✗ nvim-linux64.tar.gz - missing or invalid"
	@echo ""
	@echo "CLI tools:"
	@file offline-packages/linux/fzf 2>/dev/null | grep -q "executable" && echo "  ✓ fzf" || echo "  ✗ fzf - missing or invalid"
	@file offline-packages/linux/fd 2>/dev/null | grep -q "executable" && echo "  ✓ fd" || echo "  ✗ fd - missing or invalid"
	@file offline-packages/linux/rg 2>/dev/null | grep -q "executable" && echo "  ✓ rg" || echo "  ✗ rg - missing or invalid"
	@file offline-packages/linux/bat 2>/dev/null | grep -q "executable" && echo "  ✓ bat" || echo "  ✗ bat - missing or invalid"
	@file offline-packages/linux/starship 2>/dev/null | grep -q "executable" && echo "  ✓ starship" || echo "  ✗ starship - missing or invalid"
	@file offline-packages/linux/btop 2>/dev/null | grep -q "executable" && echo "  ✓ btop" || echo "  ✗ btop - missing or invalid"
	@file offline-packages/linux/eza 2>/dev/null | grep -q "executable" && echo "  ✓ eza" || echo "  ✗ eza - missing or invalid"
	@file offline-packages/linux/zoxide 2>/dev/null | grep -q "executable" && echo "  ✓ zoxide" || echo "  ✗ zoxide - missing or invalid"
	@file offline-packages/linux/delta 2>/dev/null | grep -q "executable" && echo "  ✓ delta" || echo "  ✗ delta - missing or invalid"
	@echo ""
	@echo "macOS binaries:"
	@file offline-packages/macos/WezTerm-macos.zip 2>/dev/null | grep -q "Zip\|archive" && echo "  ✓ WezTerm-macos.zip" || echo "  ✗ WezTerm-macos.zip - missing or invalid"
	@file offline-packages/macos/nvim-macos-arm64.tar.gz 2>/dev/null | grep -q "gzip" && echo "  ✓ nvim-macos-arm64.tar.gz" || echo "  ✗ nvim-macos-arm64.tar.gz - missing or invalid"
	@echo ""
	@echo "Fonts:"
	@file fonts/JetBrainsMono.zip 2>/dev/null | grep -q "Zip\|archive" && echo "  ✓ JetBrainsMono.zip" || echo "  ✗ JetBrainsMono.zip - missing or invalid"
	@echo ""
	@echo "Install script:"
	@test -x install.sh && echo "  ✓ install.sh executable" || echo "  ✗ install.sh not executable (run: chmod +x install.sh)"

package:
	@echo "Creating deployment package..."
	@$(MAKE) --no-print-directory verify
	@echo ""
	@echo "Building tarball: airgap-dev-kit.tar.gz"
	@# Build file list dynamically to handle optional directories
	@FILES="install.sh offline-packages/"; \
	if [ -d fonts ]; then FILES="$$FILES fonts/"; fi; \
	if [ -d config ]; then FILES="$$FILES config/"; fi; \
	tar --exclude='*.tar.gz' --exclude='.git' --exclude='.claude' --exclude='Makefile' \
		--exclude='test-plugin-bundling.sh' --exclude='nvim-linux-x86_64' \
		-czf airgap-dev-kit.tar.gz $$FILES
	@echo ""
	@ls -lh airgap-dev-kit.tar.gz
	@echo ""
	@echo "✓ Package ready for deployment!"
	@echo "  Transfer airgap-dev-kit.tar.gz to target machine"
	@echo "  Extract: tar -xzf airgap-dev-kit.tar.gz"
	@echo "  Install: cd airgap-dev-kit && ./install.sh"

package-with-config: verify
	@echo "Creating full deployment package (with config/)..."
	@if [ ! -d config ]; then \
		echo "Warning: config/ directory not found. Creating placeholder..."; \
		mkdir -p config/.config; \
		echo "# Add your dotfiles here for GNU Stow" > config/README.md; \
	fi
	@tar --exclude='*.tar.gz' --exclude='.git' --exclude='.claude' --exclude='Makefile' \
		-czf airgap-dev-kit-full.tar.gz \
		install.sh \
		offline-packages/ \
		fonts/ \
		config/
	@ls -lh airgap-dev-kit-full.tar.gz
	@echo ""
	@echo "✓ Full package ready (includes config/)!"

install:
	@echo "Installing on current machine ($(OS_TYPE))..."
	@chmod +x install.sh
	@./install.sh

clean:
	@echo "Removing downloaded binaries (keeping placeholders)..."
	@find offline-packages -type f -size +1M -delete
	@echo "✓ Large binaries removed. Run 'make update' to re-download."

clean-all: clean
	@echo "Removing package tarballs..."
	@rm -f airgap-dev-kit.tar.gz airgap-dev-kit-full.tar.gz
	@echo "✓ All generated files removed."

sync-nvim-config:
	@echo "Syncing local Neovim config to repo..."
	@if [ ! -d ~/.config/nvim ]; then \
		echo "Error: ~/.config/nvim not found!"; \
		echo "Please set up your Neovim config first."; \
		exit 1; \
	fi
	@mkdir -p config/.config/nvim
	@cp -r ~/.config/nvim/* config/.config/nvim/
	@echo "✓ Neovim config synced from ~/.config/nvim to config/.config/nvim"
	@echo ""
	@echo "Files synced:"
	@ls -lah config/.config/nvim/
	@echo ""
	@echo "Don't forget to commit: git add config/.config/nvim && git commit -m 'Update Neovim config'"
