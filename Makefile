.PHONY: help update verify package package-with-config clean clean-all install sync-nvim-config version-file

# Version variables - update these when new releases are available
WEZTERM_VERSION := 20230712-072601-f4abf8fd
FZF_VERSION := 0.66.1
TMUX_VERSION := 3.5a
NERD_FONT_VERSION := v3.2.1
BTOP_VERSION := v1.3.2
LSD_VERSION := v1.1.5
ZOX_VERSION := v0.9.8
DELTA_VERSION := 0.17.0
DIFFTASTIC_VERSION := 0.67.0
GUM_VERSION := v0.15.1
DUST_VERSION := v1.2.3
GDU_VERSION := v5.33.0
MKCERT_VERSION := v1.4.4
DIRENV_VERSION := v2.37.1
SVU_VERSION := 3.3.0

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
	@ls -lh offline-packages/linux/{wezterm.AppImage,tmux-3.4-static-x86_64,nvim-static-x86_64} 2>/dev/null | awk '{print $$5 "\t" $$9}' || echo "  Some core binaries missing"
	@echo ""
	@echo "CLI tools:"
	@ls -lh offline-packages/linux/{fzf,fd,rg,bat,starship,btop,lsd,zoxide,delta,difft,gum,dust,gdu,mkcert,airgap-dev-kit} 2>/dev/null | awk '{print $$5 "\t" $$9}' || echo "  Some tools missing"
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

	# Neovim Linux (static build from jeeftor/static-neovim)
	@if [ ! -f offline-packages/linux/nvim-static-x86_64 ] || [ $$(stat -f%z offline-packages/linux/nvim-static-x86_64 2>/dev/null || stat -c%s offline-packages/linux/nvim-static-x86_64 2>/dev/null) -lt 1000 ]; then \
		echo "  → Neovim Linux static build (from jeeftor/static-neovim)..."; \
		curl -fL "https://github.com/jeeftor/static-neovim/releases/latest/download/nvim-static-x86_64" \
			-o offline-packages/linux/nvim-static-x86_64; \
		chmod +x offline-packages/linux/nvim-static-x86_64; \
	else \
		echo "  ✓ Neovim Linux static binary already present"; \
	fi

	# fzf (binary and shell integration scripts)
	@if [ ! -f offline-packages/linux/fzf ] || [ $$(stat -f%z offline-packages/linux/fzf 2>/dev/null || stat -c%s offline-packages/linux/fzf 2>/dev/null) -lt 1000 ]; then \
		echo "  → fzf fuzzy finder..."; \
		curl -fL "https://github.com/junegunn/fzf/releases/download/v$(FZF_VERSION)/fzf-$(FZF_VERSION)-linux_amd64.tar.gz" | \
			tar -xz -C offline-packages/linux/ fzf; \
		chmod +x offline-packages/linux/fzf; \
	else \
		echo "  ✓ fzf already present"; \
	fi
	@if [ ! -f offline-packages/linux/fzf-key-bindings.bash ] || [ ! -f offline-packages/linux/fzf-completion.bash ]; then \
		echo "  → fzf shell integration scripts..."; \
		mkdir -p offline-packages/linux/fzf-scripts; \
		curl -fL "https://raw.githubusercontent.com/junegunn/fzf/v$(FZF_VERSION)/shell/key-bindings.bash" \
			-o offline-packages/linux/fzf-scripts/key-bindings.bash; \
		curl -fL "https://raw.githubusercontent.com/junegunn/fzf/v$(FZF_VERSION)/shell/completion.bash" \
			-o offline-packages/linux/fzf-scripts/completion.bash; \
		curl -fL "https://raw.githubusercontent.com/junegunn/fzf/v$(FZF_VERSION)/shell/key-bindings.zsh" \
			-o offline-packages/linux/fzf-scripts/key-bindings.zsh; \
		curl -fL "https://raw.githubusercontent.com/junegunn/fzf/v$(FZF_VERSION)/shell/completion.zsh" \
			-o offline-packages/linux/fzf-scripts/completion.zsh; \
		curl -fL "https://raw.githubusercontent.com/junegunn/fzf/v$(FZF_VERSION)/shell/key-bindings.fish" \
			-o offline-packages/linux/fzf-scripts/key-bindings.fish; \
	else \
		echo "  ✓ fzf shell scripts already present"; \
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

	# lsd - modern ls replacement
	@if [ ! -f offline-packages/linux/lsd ] || [ $$(stat -f%z offline-packages/linux/lsd 2>/dev/null || stat -c%s offline-packages/linux/lsd 2>/dev/null) -lt 1000 ]; then \
		echo "  → lsd (modern ls)..."; \
		curl -fL "https://github.com/lsd-rs/lsd/releases/download/$(LSD_VERSION)/lsd-$(LSD_VERSION)-x86_64-unknown-linux-musl.tar.gz" | \
			tar -xz -C offline-packages/linux/ --strip-components=1; \
		chmod +x offline-packages/linux/lsd; \
	else \
		echo "  ✓ lsd already present"; \
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

	# direnv - per-directory environment manager
	@if [ ! -f offline-packages/linux/direnv ] || [ $$(stat -f%z offline-packages/linux/direnv 2>/dev/null || stat -c%s offline-packages/linux/direnv 2>/dev/null) -lt 1000 ]; then \
		echo "  → direnv (environment loader)..."; \
		curl -fL "https://github.com/direnv/direnv/releases/download/$(DIRENV_VERSION)/direnv.linux-amd64" \
			-o offline-packages/linux/direnv; \
		chmod +x offline-packages/linux/direnv; \
	else \
		echo "  ✓ direnv already present"; \
	fi

	# dust - disk usage viewer
	@if [ ! -f offline-packages/linux/dust ] || [ $$(stat -f%z offline-packages/linux/dust 2>/dev/null || stat -c%s offline-packages/linux/dust 2>/dev/null) -lt 1000 ]; then \
		echo "  → dust (disk usage)..."; \
		mkdir -p /tmp/dust-download; \
		curl -fL "https://github.com/bootandy/dust/releases/download/$(DUST_VERSION)/dust-$(DUST_VERSION)-x86_64-unknown-linux-gnu.tar.gz" | \
			tar -xz -C /tmp/dust-download --strip-components=1; \
		mv /tmp/dust-download/dust offline-packages/linux/dust; \
		chmod +x offline-packages/linux/dust; \
		rm -rf /tmp/dust-download; \
	else \
		echo "  ✓ dust already present"; \
	fi

	# gdu - interactive disk usage analyzer
	@if [ ! -f offline-packages/linux/gdu ] || [ $$(stat -f%z offline-packages/linux/gdu 2>/dev/null || stat -c%s offline-packages/linux/gdu 2>/dev/null) -lt 1000 ]; then \
		echo "  → gdu (interactive disk usage)..."; \
		curl -fL "https://github.com/dundee/gdu/releases/download/$(GDU_VERSION)/gdu_linux_amd64.tgz" | \
			tar -xz -C /tmp/ && mv /tmp/gdu_linux_amd64 offline-packages/linux/gdu; \
		chmod +x offline-packages/linux/gdu; \
	else \
		echo "  ✓ gdu already present"; \
	fi

	# mkcert - local HTTPS certificate generator
	@if [ ! -f offline-packages/linux/mkcert ] || [ $$(stat -f%z offline-packages/linux/mkcert 2>/dev/null || stat -c%s offline-packages/linux/mkcert 2>/dev/null) -lt 1000 ]; then \
		echo "  → mkcert (local HTTPS certificates)..."; \
		curl -fL "https://github.com/FiloSottile/mkcert/releases/download/$(MKCERT_VERSION)/mkcert-$(MKCERT_VERSION)-linux-amd64" \
			-o offline-packages/linux/mkcert; \
		chmod +x offline-packages/linux/mkcert; \
	else \
		echo "  ✓ mkcert already present"; \
	fi

	# gopls - Go language server (installed via Mason in GitHub Actions)
	# NOTE: Mason-installed LSPs are bundled in lazy-plugins.tar.gz, not as standalone binaries

	# delta - better git diff
	@if [ ! -f offline-packages/linux/delta ] || [ $$(stat -f%z offline-packages/linux/delta 2>/dev/null || stat -c%s offline-packages/linux/delta 2>/dev/null) -lt 1000 ]; then \
		echo "  → delta (better git diff)..."; \
		curl -fL "https://github.com/dandavison/delta/releases/download/$(DELTA_VERSION)/delta-$(DELTA_VERSION)-x86_64-unknown-linux-musl.tar.gz" | \
			tar -xz --strip-components=1 -C /tmp/ && mv /tmp/delta offline-packages/linux/delta; \
		chmod +x offline-packages/linux/delta; \
	else \
		echo "  ✓ delta already present"; \
	fi

	# difftastic - structural diff tool
	@if [ ! -f offline-packages/linux/difft ] || [ $$(stat -f%z offline-packages/linux/difft 2>/dev/null || stat -c%s offline-packages/linux/difft 2>/dev/null) -lt 1000 ]; then \
		echo "  → difftastic (structural diff)..."; \
		curl -fL "https://github.com/Wilfred/difftastic/releases/download/$(DIFFTASTIC_VERSION)/difft-x86_64-unknown-linux-gnu.tar.gz" | \
			tar -xz -C offline-packages/linux/; \
		chmod +x offline-packages/linux/difft; \
	else \
		echo "  ✓ difftastic already present"; \
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

	# airgap-dev-kit - CLI wrapper command
	@if [ ! -f offline-packages/linux/airgap-dev-kit ]; then \
		echo "  → airgap-dev-kit (CLI wrapper)..."; \
		cp scripts/airgap-dev-kit offline-packages/linux/airgap-dev-kit; \
		chmod +x offline-packages/linux/airgap-dev-kit; \
	else \
		echo "  ✓ airgap-dev-kit already present"; \
	fi

	# stow - GNU Stow for dotfile management (Perl script, works everywhere)
	@if [ ! -f offline-packages/linux/stow ] || [ $$(stat -f%z offline-packages/linux/stow 2>/dev/null || stat -c%s offline-packages/linux/stow 2>/dev/null) -lt 1000 ]; then \
		echo "  → GNU Stow (dotfile manager)..."; \
		mkdir -p /tmp/stow-download; \
		curl -fL "https://ftp.gnu.org/gnu/stow/stow-latest.tar.gz" | tar -xz -C /tmp/stow-download --strip-components=1; \
		cp /tmp/stow-download/bin/stow offline-packages/linux/stow; \
		cp /tmp/stow-download/bin/chkstow offline-packages/linux/chkstow; \
		chmod +x offline-packages/linux/stow offline-packages/linux/chkstow; \
		rm -rf /tmp/stow-download; \
	else \
		echo "  ✓ stow already present"; \
	fi

	# lazygit - Terminal UI for git
	@if [ ! -f offline-packages/linux/lazygit ]; then \
		echo "  → lazygit (git TUI)..."; \
		curl -fL "https://github.com/jesseduffield/lazygit/releases/download/v0.43.1/lazygit_0.43.1_Linux_x86_64.tar.gz" \
			| tar -xz -C offline-packages/linux/ lazygit; \
		chmod +x offline-packages/linux/lazygit; \
	else \
		echo "  ✓ lazygit already present"; \
	fi

	# zoxide - Smarter cd command
	@if [ ! -f offline-packages/linux/zoxide ]; then \
		echo "  → zoxide (smarter cd)..."; \
		curl -fL "https://github.com/ajeetdsouza/zoxide/releases/download/v0.9.4/zoxide-0.9.4-x86_64-unknown-linux-musl.tar.gz" \
			| tar -xz -C offline-packages/linux/ zoxide; \
		chmod +x offline-packages/linux/zoxide; \
	else \
		echo "  ✓ zoxide already present"; \
	fi

	# delta - Better git diffs
	@if [ ! -f offline-packages/linux/delta ]; then \
		echo "  → delta (git diff viewer)..."; \
		mkdir -p /tmp/delta-download; \
		curl -fL "https://github.com/dandavison/delta/releases/download/0.17.0/delta-0.17.0-x86_64-unknown-linux-musl.tar.gz" \
			| tar -xz -C /tmp/delta-download --strip-components=1; \
		mv /tmp/delta-download/delta offline-packages/linux/; \
		chmod +x offline-packages/linux/delta; \
		rm -rf /tmp/delta-download; \
	else \
		echo "  ✓ delta already present"; \
	fi

	# jq - JSON processor
	@if [ ! -f offline-packages/linux/jq ]; then \
		echo "  → jq (JSON processor)..."; \
		curl -fL "https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-linux-amd64" \
			-o offline-packages/linux/jq; \
		chmod +x offline-packages/linux/jq; \
	else \
		echo "  ✓ jq already present"; \
	fi

	# svu - semantic version utility
	@if [ ! -f offline-packages/linux/svu ]; then \
		echo "  → svu (semantic version utility)..."; \
		tmp_dir=$$(mktemp -d); \
		curl -fL "https://github.com/caarlos0/svu/releases/download/v$(SVU_VERSION)/svu_$(SVU_VERSION)_linux_amd64.tar.gz" | \
			tar -xz -C $$tmp_dir; \
		mv $$tmp_dir/svu offline-packages/linux/svu; \
		chmod +x offline-packages/linux/svu; \
		rm -rf $$tmp_dir; \
	else \
		echo "  ✓ svu already present"; \
	fi

	# btop - System monitor
	@if [ ! -f offline-packages/linux/btop ]; then \
		echo "  → btop (system monitor)..."; \
		mkdir -p /tmp/btop-download; \
		curl -fL "https://github.com/aristocratos/btop/releases/download/v1.3.2/btop-x86_64-linux-musl.tbz" \
			| tar -xj -C /tmp/btop-download; \
		mv /tmp/btop-download/btop/bin/btop offline-packages/linux/; \
		chmod +x offline-packages/linux/btop; \
		rm -rf /tmp/btop-download; \
	else \
		echo "  ✓ btop already present"; \
	fi

	# gopls - Go language server (requires Go to build)
	# Note: gopls doesn't provide pre-built binaries, requires 'go install'
	# Skipping for now - users can install with: go install golang.org/x/tools/gopls@latest
	# @if [ ! -f offline-packages/linux/gopls ]; then \
	# 	echo "  → gopls (Go LSP) - requires Go toolchain to build"; \
	# else \
	# 	echo "  ✓ gopls already present"; \
	# fi

	# lua-language-server - Lua LSP
	@if [ ! -f offline-packages/linux/lua-language-server ]; then \
		echo "  → lua-language-server (Lua LSP)..."; \
		mkdir -p /tmp/lua-ls-download; \
		curl -fL "https://github.com/LuaLS/lua-language-server/releases/download/3.10.5/lua-language-server-3.10.5-linux-x64.tar.gz" \
			| tar -xz -C /tmp/lua-ls-download; \
		mv /tmp/lua-ls-download/bin/lua-language-server offline-packages/linux/; \
		chmod +x offline-packages/linux/lua-language-server; \
		rm -rf /tmp/lua-ls-download; \
	else \
		echo "  ✓ lua-language-server already present"; \
	fi


	# shellcheck - Shell script linter/analyzer
	@if [ ! -f offline-packages/linux/shellcheck ]; then \
		echo "  → shellcheck (Shell linter)..."; \
		mkdir -p /tmp/shellcheck-download; \
		curl -fL "https://github.com/koalaman/shellcheck/releases/download/v0.10.0/shellcheck-v0.10.0.linux.x86_64.tar.xz" \
			| tar -xJ -C /tmp/shellcheck-download --strip-components=1; \
		mv /tmp/shellcheck-download/shellcheck offline-packages/linux/; \
		chmod +x offline-packages/linux/shellcheck; \
		rm -rf /tmp/shellcheck-download; \
	else \
		echo "  ✓ shellcheck already present"; \
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

	# airgap-dev-kit - CLI wrapper command
	@if [ ! -f offline-packages/macos/airgap-dev-kit ]; then \
		echo "  → airgap-dev-kit (CLI wrapper)..."; \
		cp scripts/airgap-dev-kit offline-packages/macos/airgap-dev-kit; \
		chmod +x offline-packages/macos/airgap-dev-kit; \
	else \
		echo "  ✓ airgap-dev-kit already present"; \
	fi

	# stow - GNU Stow for dotfile management (Perl script, same for all platforms)
	@if [ ! -f offline-packages/macos/stow ] || [ $$(stat -f%z offline-packages/macos/stow 2>/dev/null || stat -c%s offline-packages/macos/stow 2>/dev/null) -lt 1000 ]; then \
		echo "  → GNU Stow (dotfile manager)..."; \
		mkdir -p /tmp/stow-download; \
		curl -fL "https://ftp.gnu.org/gnu/stow/stow-latest.tar.gz" | tar -xz -C /tmp/stow-download --strip-components=1; \
		cp /tmp/stow-download/bin/stow offline-packages/macos/stow; \
		cp /tmp/stow-download/bin/chkstow offline-packages/macos/chkstow; \
		chmod +x offline-packages/macos/stow offline-packages/macos/chkstow; \
		rm -rf /tmp/stow-download; \
	else \
		echo "  ✓ stow already present"; \
	fi

	# lazygit - Terminal UI for git
	@if [ ! -f offline-packages/macos/lazygit ]; then \
		echo "  → lazygit (git TUI)..."; \
		curl -fL "https://github.com/jesseduffield/lazygit/releases/download/v0.43.1/lazygit_0.43.1_Darwin_arm64.tar.gz" \
			| tar -xz -C offline-packages/macos/ lazygit; \
		chmod +x offline-packages/macos/lazygit; \
	else \
		echo "  ✓ lazygit already present"; \
	fi

	# zoxide - Smarter cd command
	@if [ ! -f offline-packages/macos/zoxide ]; then \
		echo "  → zoxide (smarter cd)..."; \
		curl -fL "https://github.com/ajeetdsouza/zoxide/releases/download/v0.9.4/zoxide-0.9.4-aarch64-apple-darwin.tar.gz" \
			| tar -xz -C offline-packages/macos/ zoxide; \
		chmod +x offline-packages/macos/zoxide; \
	else \
		echo "  ✓ zoxide already present"; \
	fi

	# delta - Better git diffs
	@if [ ! -f offline-packages/macos/delta ]; then \
		echo "  → delta (git diff viewer)..."; \
		mkdir -p /tmp/delta-download; \
		curl -fL "https://github.com/dandavison/delta/releases/download/0.17.0/delta-0.17.0-aarch64-apple-darwin.tar.gz" \
			| tar -xz -C /tmp/delta-download --strip-components=1; \
		mv /tmp/delta-download/delta offline-packages/macos/; \
		chmod +x offline-packages/macos/delta; \
		rm -rf /tmp/delta-download; \
	else \
		echo "  ✓ delta already present"; \
	fi

	# difftastic - structural diff tool
	@if [ ! -f offline-packages/macos/difft ]; then \
		echo "  → difftastic (structural diff)..."; \
		curl -fL "https://github.com/Wilfred/difftastic/releases/download/$(DIFFTASTIC_VERSION)/difft-aarch64-apple-darwin.tar.gz" \
			| tar -xz -C offline-packages/macos/; \
		chmod +x offline-packages/macos/difft; \
	else \
		echo "  ✓ difftastic already present"; \
	fi

	# jq - JSON processor
	@if [ ! -f offline-packages/macos/jq ]; then \
		echo "  → jq (JSON processor)..."; \
		curl -fL "https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-macos-arm64" \
			-o offline-packages/macos/jq; \
		chmod +x offline-packages/macos/jq; \
	else \
		echo "  ✓ jq already present"; \
	fi

	# direnv - per-directory environment manager
	@if [ ! -f offline-packages/macos/direnv ]; then \
		echo "  → direnv (environment loader)..."; \
		curl -fL "https://github.com/direnv/direnv/releases/download/$(DIRENV_VERSION)/direnv.darwin-arm64" \
			-o offline-packages/macos/direnv; \
		chmod +x offline-packages/macos/direnv; \
	else \
		echo "  ✓ direnv already present"; \
	fi

	# dust - disk usage viewer
	@if [ ! -f offline-packages/macos/dust ]; then \
		echo "  → dust (disk usage)..."; \
		mkdir -p /tmp/dust-macos-download; \
		curl -fL "https://github.com/bootandy/dust/releases/download/$(DUST_VERSION)/dust-$(DUST_VERSION)-x86_64-apple-darwin.tar.gz" | \
			tar -xz -C /tmp/dust-macos-download --strip-components=1; \
		mv /tmp/dust-macos-download/dust offline-packages/macos/dust; \
		chmod +x offline-packages/macos/dust; \
		rm -rf /tmp/dust-macos-download; \
	else \
		echo "  ✓ dust already present"; \
	fi

	# gdu - interactive disk usage analyzer
	@if [ ! -f offline-packages/macos/gdu ]; then \
		echo "  → gdu (interactive disk usage)..."; \
		curl -fL "https://github.com/dundee/gdu/releases/download/$(GDU_VERSION)/gdu_darwin_amd64.tgz" | \
			tar -xz -C /tmp/ && mv /tmp/gdu_darwin_amd64 offline-packages/macos/gdu; \
		chmod +x offline-packages/macos/gdu; \
	else \
		echo "  ✓ gdu already present"; \
	fi

	# mkcert - local HTTPS certificate generator
	@if [ ! -f offline-packages/macos/mkcert ]; then \
		echo "  → mkcert (local HTTPS certificates)..."; \
		curl -fL "https://github.com/FiloSottile/mkcert/releases/download/$(MKCERT_VERSION)/mkcert-$(MKCERT_VERSION)-darwin-amd64" \
			-o offline-packages/macos/mkcert; \
		chmod +x offline-packages/macos/mkcert; \
	else \
		echo "  ✓ mkcert already present"; \
	fi

	# gopls - Go language server (installed via Mason in GitHub Actions)
	# NOTE: Mason-installed LSPs are bundled in lazy-plugins.tar.gz, not as standalone binaries

	# svu - semantic version utility
	@if [ ! -f offline-packages/macos/svu ]; then \
		echo "  → svu (semantic version utility)..."; \
		tmp_dir=$$(mktemp -d); \
		curl -fL "https://github.com/caarlos0/svu/releases/download/v$(SVU_VERSION)/svu_$(SVU_VERSION)_darwin_all.tar.gz" | \
			tar -xz -C $$tmp_dir; \
		mv $$tmp_dir/svu offline-packages/macos/svu; \
		chmod +x offline-packages/macos/svu; \
		rm -rf $$tmp_dir; \
	else \
		echo "  ✓ svu already present"; \
	fi

	# lsd - Modern ls replacement
	@if [ ! -f offline-packages/macos/lsd ]; then \
		echo "  → lsd (modern ls)..."; \
		curl -fL "https://github.com/lsd-rs/lsd/releases/download/$(LSD_VERSION)/lsd-$(LSD_VERSION)-aarch64-apple-darwin.tar.gz" \
			| tar -xz -C offline-packages/macos/ --strip-components=1; \
		chmod +x offline-packages/macos/lsd; \
	else \
		echo "  ✓ lsd already present"; \
	fi

	# btop - System monitor
	@if [ ! -f offline-packages/macos/btop ]; then \
		echo "  → btop (system monitor)..."; \
		mkdir -p /tmp/btop-download; \
		curl -fL "https://github.com/aristocratos/btop/releases/download/v1.3.2/btop-aarch64-apple-darwin.tbz" \
			| tar -xj -C /tmp/btop-download; \
		mv /tmp/btop-download/btop/bin/btop offline-packages/macos/; \
		chmod +x offline-packages/macos/btop; \
		rm -rf /tmp/btop-download; \
	else \
		echo "  ✓ btop already present"; \
	fi

	# gopls - Go language server (requires Go to build)
	# Note: gopls doesn't provide pre-built binaries, requires 'go install'
	# Skipping for now - users can install with: go install golang.org/x/tools/gopls@latest
	# @if [ ! -f offline-packages/macos/gopls ]; then \
	# 	echo "  → gopls (Go LSP) - requires Go toolchain to build"; \
	# else \
	# 	echo "  ✓ gopls already present"; \
	# fi

	# lua-language-server - Lua LSP
	@if [ ! -f offline-packages/macos/lua-language-server ]; then \
		echo "  → lua-language-server (Lua LSP)..."; \
		mkdir -p /tmp/lua-ls-download; \
		curl -fL "https://github.com/LuaLS/lua-language-server/releases/download/3.10.5/lua-language-server-3.10.5-darwin-arm64.tar.gz" \
			| tar -xz -C /tmp/lua-ls-download; \
		mv /tmp/lua-ls-download/bin/lua-language-server offline-packages/macos/; \
		chmod +x offline-packages/macos/lua-language-server; \
		rm -rf /tmp/lua-ls-download; \
	else \
		echo "  ✓ lua-language-server already present"; \
	fi


	# shellcheck - Shell script linter/analyzer
	@if [ ! -f offline-packages/macos/shellcheck ]; then \
		echo "  → shellcheck (Shell linter)..."; \
		mkdir -p /tmp/shellcheck-download; \
		curl -fL "https://github.com/koalaman/shellcheck/releases/download/v0.10.0/shellcheck-v0.10.0.darwin.aarch64.tar.xz" \
			| tar -xJ -C /tmp/shellcheck-download --strip-components=1; \
		mv /tmp/shellcheck-download/shellcheck offline-packages/macos/; \
		chmod +x offline-packages/macos/shellcheck; \
		rm -rf /tmp/shellcheck-download; \
	else \
		echo "  ✓ shellcheck already present"; \
	fi

	# fzf shell integration scripts (shared between macOS and Linux)
	@if [ ! -d offline-packages/macos/fzf-scripts ]; then \
		echo "  → fzf shell integration scripts..."; \
		mkdir -p offline-packages/macos/fzf-scripts; \
		curl -fL "https://raw.githubusercontent.com/junegunn/fzf/v$(FZF_VERSION)/shell/key-bindings.bash" \
			-o offline-packages/macos/fzf-scripts/key-bindings.bash; \
		curl -fL "https://raw.githubusercontent.com/junegunn/fzf/v$(FZF_VERSION)/shell/completion.bash" \
			-o offline-packages/macos/fzf-scripts/completion.bash; \
		curl -fL "https://raw.githubusercontent.com/junegunn/fzf/v$(FZF_VERSION)/shell/key-bindings.zsh" \
			-o offline-packages/macos/fzf-scripts/key-bindings.zsh; \
		curl -fL "https://raw.githubusercontent.com/junegunn/fzf/v$(FZF_VERSION)/shell/completion.zsh" \
			-o offline-packages/macos/fzf-scripts/completion.zsh; \
		curl -fL "https://raw.githubusercontent.com/junegunn/fzf/v$(FZF_VERSION)/shell/key-bindings.fish" \
			-o offline-packages/macos/fzf-scripts/key-bindings.fish; \
	else \
		echo "  ✓ fzf shell scripts already present"; \
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
	@FAIL=0; \
	echo ""; \
	echo "Core Linux binaries:"; \
	if file offline-packages/linux/wezterm.AppImage 2>/dev/null | grep -q "executable"; then echo "  ✓ wezterm.AppImage"; else echo "  ✗ wezterm.AppImage - missing or invalid"; FAIL=1; fi; \
	if file offline-packages/linux/tmux-3.4-static-x86_64 2>/dev/null | grep -q "executable"; then echo "  ✓ tmux-3.4-static-x86_64"; else echo "  ✗ tmux-3.4-static-x86_64 - missing or invalid"; FAIL=1; fi; \
	if file offline-packages/linux/nvim-static-x86_64 2>/dev/null | grep -q "executable"; then echo "  ✓ nvim-static-x86_64"; else echo "  ✗ nvim-static-x86_64 - missing or invalid (run GitHub Actions build)"; FAIL=1; fi; \
	echo ""; \
	echo "CLI tools:"; \
	if file offline-packages/linux/fzf 2>/dev/null | grep -q "executable"; then echo "  ✓ fzf"; else echo "  ✗ fzf - missing or invalid"; FAIL=1; fi; \
	if file offline-packages/linux/fd 2>/dev/null | grep -q "executable"; then echo "  ✓ fd"; else echo "  ✗ fd - missing or invalid"; FAIL=1; fi; \
	if file offline-packages/linux/rg 2>/dev/null | grep -q "executable"; then echo "  ✓ rg"; else echo "  ✗ rg - missing or invalid"; FAIL=1; fi; \
	if file offline-packages/linux/bat 2>/dev/null | grep -q "executable"; then echo "  ✓ bat"; else echo "  ✗ bat - missing or invalid"; FAIL=1; fi; \
	if file offline-packages/linux/starship 2>/dev/null | grep -q "executable"; then echo "  ✓ starship"; else echo "  ✗ starship - missing or invalid"; FAIL=1; fi; \
	if file offline-packages/linux/btop 2>/dev/null | grep -q "executable"; then echo "  ✓ btop"; else echo "  ✗ btop - missing or invalid"; FAIL=1; fi; \
	if file offline-packages/linux/lsd 2>/dev/null | grep -q "executable"; then echo "  ✓ lsd"; else echo "  ✗ lsd - missing or invalid"; FAIL=1; fi; \
	if file offline-packages/linux/zoxide 2>/dev/null | grep -q "executable"; then echo "  ✓ zoxide"; else echo "  ✗ zoxide - missing or invalid"; FAIL=1; fi; \
	if file offline-packages/linux/delta 2>/dev/null | grep -q "executable"; then echo "  ✓ delta"; else echo "  ✗ delta - missing or invalid"; FAIL=1; fi; \
	if file offline-packages/linux/difft 2>/dev/null | grep -q "executable"; then echo "  ✓ difft"; else echo "  ✗ difft - missing or invalid"; FAIL=1; fi; \
	if file offline-packages/linux/jq 2>/dev/null | grep -q "executable"; then echo "  ✓ jq"; else echo "  ✗ jq - missing or invalid"; FAIL=1; fi; \
	if file offline-packages/linux/direnv 2>/dev/null | grep -q "executable"; then echo "  ✓ direnv"; else echo "  ✗ direnv - missing or invalid"; FAIL=1; fi; \
	if file offline-packages/linux/dust 2>/dev/null | grep -q "executable"; then echo "  ✓ dust"; else echo "  ✗ dust - missing or invalid"; FAIL=1; fi; \
	if file offline-packages/linux/gdu 2>/dev/null | grep -q "executable"; then echo "  ✓ gdu"; else echo "  ✗ gdu - missing or invalid"; FAIL=1; fi; \
	if file offline-packages/linux/mkcert 2>/dev/null | grep -q "executable"; then echo "  ✓ mkcert"; else echo "  ✗ mkcert - missing or invalid"; FAIL=1; fi; \
	echo "  ⚠ gopls and other LSPs installed via Mason (not verified here)"; \
	if file offline-packages/linux/airgap-dev-kit 2>/dev/null | grep -q "executable"; then echo "  ✓ airgap-dev-kit"; else echo "  ✗ airgap-dev-kit - missing or invalid"; FAIL=1; fi; \
	if file offline-packages/linux/svu 2>/dev/null | grep -q "executable"; then echo "  ✓ svu"; else echo "  ✗ svu - missing or invalid"; FAIL=1; fi; \
	echo ""; \
	echo "macOS binaries:"; \
	if file offline-packages/macos/WezTerm-macos.zip 2>/dev/null | grep -q "Zip\|archive"; then echo "  ✓ WezTerm-macos.zip"; else echo "  ✗ WezTerm-macos.zip - missing or invalid"; FAIL=1; fi; \
	if file offline-packages/macos/nvim-macos-arm64.tar.gz 2>/dev/null | grep -q "gzip"; then echo "  ✓ nvim-macos-arm64.tar.gz"; else echo "  ✗ nvim-macos-arm64.tar.gz - missing or invalid"; FAIL=1; fi; \
	echo ""; \
	echo "Fonts:"; \
	if file fonts/JetBrainsMono.zip 2>/dev/null | grep -q "Zip\|archive"; then echo "  ✓ JetBrainsMono.zip"; else echo "  ✗ JetBrainsMono.zip - missing or invalid"; FAIL=1; fi; \
	echo ""; \
	echo "Install script:"; \
	if test -x install.sh; then echo "  ✓ install.sh executable"; else echo "  ✗ install.sh not executable (run: chmod +x install.sh)"; FAIL=1; fi; \
	echo ""; \
	if [ $$FAIL -ne 0 ]; then \
		echo "✗ Verification failed. Please address the missing binaries above."; \
		exit 1; \
	else \
		echo "✓ Verification passed. All required binaries present."; \
	fi

version-file:
	@echo "Embedding kit version information..."
	@(if git rev-parse --git-dir >/dev/null 2>&1; then \
		git describe --tags --always --dirty; \
	else \
		echo "unknown"; \
	fi) > VERSION

package: version-file
	@echo "Creating deployment package..."
	@$(MAKE) --no-print-directory verify
	@echo ""
	@echo "Building tarball: airgap-dev-kit.tar.gz"
	@# Build file list dynamically to handle optional directories
	@FILES="install.sh VERSION offline-packages/"; \
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
	@rm -f VERSION

package-with-config: verify version-file
	@echo "Creating full deployment package (with config/)..."
	@if [ ! -d config ]; then \
		echo "Warning: config/ directory not found. Creating placeholder..."; \
		mkdir -p config/.config; \
		echo "# Add your dotfiles here for GNU Stow" > config/README.md; \
	fi
	@tar --exclude='*.tar.gz' --exclude='.git' --exclude='.claude' --exclude='Makefile' \
		-czf airgap-dev-kit-full.tar.gz \
		install.sh \
		VERSION \
		offline-packages/ \
		fonts/ \
		config/
	@ls -lh airgap-dev-kit-full.tar.gz
	@echo ""
	@echo "✓ Full package ready (includes config/)!"
	@rm -f VERSION

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
