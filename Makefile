.PHONY: help update verify package package-cli package-v2 package-with-config download-release docker-test test-cli-package test-update-tools check-updates check-updates-strict clean clean-all install sync-nvim-config version-file airgap

# Version variables - update these when new releases are available
WEZTERM_VERSION := 20240203-110809-5046fc22
FZF_VERSION := 0.74.2
TMUX_VERSION := 3.5a
NERD_FONT_VERSION := v3.5.0
NVIM_VERSION := v0.12.4
BTOP_VERSION := v1.4.7
LSD_VERSION := v1.2.0
ZOX_VERSION := v0.10.0
DELTA_VERSION := 0.19.2
DIFFTASTIC_VERSION := 0.70.0
GUM_VERSION := v0.17.0
GLOW_VERSION := v2.1.2
BROOT_VERSION := v1.58.0
FASTFETCH_VERSION := 2.67.1
DUST_VERSION := v1.2.4
GDU_VERSION := v5.36.1
USBTREE_VERSION := v0.1.1
MKCERT_VERSION := v1.4.4
DIRENV_VERSION := v2.37.1
SVU_VERSION := 3.4.1
GPING_VERSION := 1.20.4
FD_VERSION := 10.4.2
RG_VERSION := 15.2.0
BAT_VERSION := 0.26.1
STARSHIP_VERSION := 1.26.0
RELEASE_DIR ?= .

help:
	@echo "Air-Gap Dev Kit - Makefile Commands"
	@echo "===================================="
	@echo "make update            - Download all missing binaries"
	@echo "make verify            - Verify all binaries are present and valid"
	@echo "make package           - Create tarball for offline deployment"
	@echo "make package-cli       - Create CLI-only tarball without GUI tools or fonts"
	@echo "make package-v2        - Create target-aware v2 kit (BINARY=path/to/airgap)"
	@echo "make download-release  - Download and verify the latest Linux release package"
	@echo "make docker-test       - Package and smoke test install/remove in Docker"
	@echo "make test-cli-package  - Test the CLI-only package and installer mode"
	@echo "make test-update-tools - Test automated version-update planning"
	@echo "make check-updates     - Check for newer tool releases (run on online machine)"
	@echo "make check-updates-strict - Check releases and fail if updates are available"
	@echo "make install           - Install on current machine (runs install.sh)"
	@echo "make sync              - Rsync repo to jstein@ai:~/airgap-dev-kit (for local testing)"
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
	@ls -lh offline-packages/linux/{fzf,fd,rg,bat,starship,btop,lsd,zoxide,delta,difft,gum,glow,broot,fastfetch,dust,gdu,usbtree,mkcert,airgap-dev-kit,lazygit,jq,gping,svu,lua-language-server,shellcheck} 2>/dev/null | awk '{print $$5 "\t" $$9}' || echo "  Some tools missing"
	@echo ""
	@echo "Fonts:"
	@ls -lh fonts/JetBrainsMono.zip 2>/dev/null | awk '{print $$5 "\t" $$9}' || echo "  Font missing"

update: update-linux update-fonts
	@echo ""
	@echo "✓ All Linux binaries downloaded!"
	@echo "Run 'make verify' to check integrity"

update-linux:
	@echo "Downloading Linux binaries..."
	@mkdir -p offline-packages/linux

	@# WezTerm AppImage
	@if [ ! -f offline-packages/linux/wezterm.AppImage ] || [ $$(stat -f%z offline-packages/linux/wezterm.AppImage 2>/dev/null || stat -c%s offline-packages/linux/wezterm.AppImage 2>/dev/null) -lt 1000 ]; then \
		echo "  → WezTerm AppImage..."; \
		curl -fsSL "https://github.com/wez/wezterm/releases/download/$(WEZTERM_VERSION)/WezTerm-$(WEZTERM_VERSION)-Ubuntu20.04.AppImage" \
			-o offline-packages/linux/wezterm.AppImage; \
		chmod +x offline-packages/linux/wezterm.AppImage; \
	else \
		echo "  ✓ WezTerm AppImage already present"; \
	fi

	@# tmux AppImage
	@if [ ! -f offline-packages/linux/tmux-3.4-static-x86_64 ] || [ $$(stat -f%z offline-packages/linux/tmux-3.4-static-x86_64 2>/dev/null || stat -c%s offline-packages/linux/tmux-3.4-static-x86_64 2>/dev/null) -lt 1000 ]; then \
		echo "  → tmux AppImage..."; \
		curl -fsSL "https://github.com/nelsonenzo/tmux-appimage/releases/download/$(TMUX_VERSION)/tmux.appimage" \
			-o offline-packages/linux/tmux-3.4-static-x86_64; \
		chmod +x offline-packages/linux/tmux-3.4-static-x86_64; \
	else \
		echo "  ✓ tmux already present"; \
	fi

	@# Neovim Linux (official release tarball - includes runtime files)
	@if [ ! -f offline-packages/linux/nvim-static-x86_64 ] || [ $$(stat -f%z offline-packages/linux/nvim-static-x86_64 2>/dev/null || stat -c%s offline-packages/linux/nvim-static-x86_64 2>/dev/null) -lt 1000 ] || [ ! -f offline-packages/linux/nvim-runtime/syntax/syntax.vim ]; then \
		set -e; \
		echo "  → Neovim Linux (official $(NVIM_VERSION))..."; \
		rm -rf /tmp/nvim-dl offline-packages/linux/nvim-runtime; \
		mkdir -p /tmp/nvim-dl offline-packages/linux/nvim-runtime; \
		curl -fsSL "https://github.com/neovim/neovim/releases/download/$(NVIM_VERSION)/nvim-linux-x86_64.tar.gz" | \
			tar -xz -C /tmp/nvim-dl --strip-components=1; \
		cp /tmp/nvim-dl/bin/nvim offline-packages/linux/nvim-static-x86_64; \
		chmod +x offline-packages/linux/nvim-static-x86_64; \
		cp -R /tmp/nvim-dl/share/nvim/runtime/. offline-packages/linux/nvim-runtime/; \
		rm -rf /tmp/nvim-dl; \
	else \
		echo "  ✓ Neovim Linux binary already present"; \
	fi

	@# fzf (binary and shell integration scripts)
	@if [ ! -f offline-packages/linux/fzf ] || [ $$(stat -f%z offline-packages/linux/fzf 2>/dev/null || stat -c%s offline-packages/linux/fzf 2>/dev/null) -lt 1000 ]; then \
		echo "  → fzf fuzzy finder..."; \
		curl -fsSL "https://github.com/junegunn/fzf/releases/download/v$(FZF_VERSION)/fzf-$(FZF_VERSION)-linux_amd64.tar.gz" | \
			tar -xz -C offline-packages/linux/ fzf; \
		chmod +x offline-packages/linux/fzf; \
	else \
		echo "  ✓ fzf already present"; \
	fi
	@if [ ! -f offline-packages/linux/fzf-scripts/key-bindings.bash ] || [ ! -f offline-packages/linux/fzf-scripts/completion.bash ]; then \
		echo "  → fzf shell integration scripts..."; \
		mkdir -p offline-packages/linux/fzf-scripts; \
		curl -fsSL "https://raw.githubusercontent.com/junegunn/fzf/v$(FZF_VERSION)/shell/key-bindings.bash" \
			-o offline-packages/linux/fzf-scripts/key-bindings.bash; \
		curl -fsSL "https://raw.githubusercontent.com/junegunn/fzf/v$(FZF_VERSION)/shell/completion.bash" \
			-o offline-packages/linux/fzf-scripts/completion.bash; \
		curl -fsSL "https://raw.githubusercontent.com/junegunn/fzf/v$(FZF_VERSION)/shell/key-bindings.zsh" \
			-o offline-packages/linux/fzf-scripts/key-bindings.zsh; \
		curl -fsSL "https://raw.githubusercontent.com/junegunn/fzf/v$(FZF_VERSION)/shell/completion.zsh" \
			-o offline-packages/linux/fzf-scripts/completion.zsh; \
		curl -fsSL "https://raw.githubusercontent.com/junegunn/fzf/v$(FZF_VERSION)/shell/key-bindings.fish" \
			-o offline-packages/linux/fzf-scripts/key-bindings.fish; \
	else \
		echo "  ✓ fzf shell scripts already present"; \
	fi

	@# fd - fast find replacement
	@if [ ! -f offline-packages/linux/fd ] || [ $$(stat -f%z offline-packages/linux/fd 2>/dev/null || stat -c%s offline-packages/linux/fd 2>/dev/null) -lt 1000 ]; then \
		echo "  → fd (fast find)..."; \
		mkdir -p /tmp/fd-dl; \
		curl -fsSL "https://github.com/sharkdp/fd/releases/download/v$(FD_VERSION)/fd-v$(FD_VERSION)-x86_64-unknown-linux-musl.tar.gz" | \
			tar -xz -C /tmp/fd-dl --strip-components=1; \
		mv /tmp/fd-dl/fd offline-packages/linux/fd; \
		chmod +x offline-packages/linux/fd; \
		rm -rf /tmp/fd-dl; \
	else \
		echo "  ✓ fd already present"; \
	fi

	@# ripgrep - fast grep replacement
	@if [ ! -f offline-packages/linux/rg ] || [ $$(stat -f%z offline-packages/linux/rg 2>/dev/null || stat -c%s offline-packages/linux/rg 2>/dev/null) -lt 1000 ]; then \
		echo "  → ripgrep (fast grep)..."; \
		mkdir -p /tmp/rg-dl; \
		curl -fsSL "https://github.com/BurntSushi/ripgrep/releases/download/$(RG_VERSION)/ripgrep-$(RG_VERSION)-x86_64-unknown-linux-musl.tar.gz" | \
			tar -xz -C /tmp/rg-dl --strip-components=1; \
		mv /tmp/rg-dl/rg offline-packages/linux/rg; \
		chmod +x offline-packages/linux/rg; \
		rm -rf /tmp/rg-dl; \
	else \
		echo "  ✓ rg already present"; \
	fi

	@# bat - syntax-highlighting cat replacement
	@if [ ! -f offline-packages/linux/bat ] || [ $$(stat -f%z offline-packages/linux/bat 2>/dev/null || stat -c%s offline-packages/linux/bat 2>/dev/null) -lt 1000 ]; then \
		echo "  → bat (syntax-highlighting cat)..."; \
		mkdir -p /tmp/bat-dl; \
		curl -fsSL "https://github.com/sharkdp/bat/releases/download/v$(BAT_VERSION)/bat-v$(BAT_VERSION)-x86_64-unknown-linux-musl.tar.gz" | \
			tar -xz -C /tmp/bat-dl --strip-components=1; \
		mv /tmp/bat-dl/bat offline-packages/linux/bat; \
		chmod +x offline-packages/linux/bat; \
		rm -rf /tmp/bat-dl; \
	else \
		echo "  ✓ bat already present"; \
	fi

	@# starship - cross-shell prompt
	@if [ ! -f offline-packages/linux/starship ] || [ $$(stat -f%z offline-packages/linux/starship 2>/dev/null || stat -c%s offline-packages/linux/starship 2>/dev/null) -lt 1000 ]; then \
		echo "  → starship (cross-shell prompt)..."; \
		curl -fsSL "https://github.com/starship/starship/releases/download/v$(STARSHIP_VERSION)/starship-x86_64-unknown-linux-musl.tar.gz" | \
			tar -xz -C offline-packages/linux/ starship; \
		chmod +x offline-packages/linux/starship; \
	else \
		echo "  ✓ starship already present"; \
	fi

	@# btop - resource monitor
	@if [ ! -f offline-packages/linux/btop ] || [ $$(stat -f%z offline-packages/linux/btop 2>/dev/null || stat -c%s offline-packages/linux/btop 2>/dev/null) -lt 1000 ]; then \
		echo "  → btop (resource monitor)..."; \
		curl -fsSL "https://github.com/aristocratos/btop/releases/download/$(BTOP_VERSION)/btop-x86_64-unknown-linux-musl.tar.gz" | \
			tar -xz -C /tmp/ && mv /tmp/btop/bin/btop offline-packages/linux/btop && rm -rf /tmp/btop; \
		chmod +x offline-packages/linux/btop; \
	else \
		echo "  ✓ btop already present"; \
	fi

	@# lsd - modern ls replacement
	@if [ ! -f offline-packages/linux/lsd ] || [ $$(stat -f%z offline-packages/linux/lsd 2>/dev/null || stat -c%s offline-packages/linux/lsd 2>/dev/null) -lt 1000 ]; then \
		echo "  → lsd (modern ls)..."; \
		curl -fsSL "https://github.com/lsd-rs/lsd/releases/download/$(LSD_VERSION)/lsd-$(LSD_VERSION)-x86_64-unknown-linux-musl.tar.gz" | \
			tar -xz -C offline-packages/linux/ --strip-components=1; \
		chmod +x offline-packages/linux/lsd; \
	else \
		echo "  ✓ lsd already present"; \
	fi

	@# zoxide - smarter cd
	@if [ ! -f offline-packages/linux/zoxide ] || [ $$(stat -f%z offline-packages/linux/zoxide 2>/dev/null || stat -c%s offline-packages/linux/zoxide 2>/dev/null) -lt 1000 ]; then \
		echo "  → zoxide (smarter cd)..."; \
		curl -fsSL "https://github.com/ajeetdsouza/zoxide/releases/download/$(ZOX_VERSION)/zoxide-$$(echo $(ZOX_VERSION) | sed 's/^v//')-x86_64-unknown-linux-musl.tar.gz" | \
			tar -xz -C offline-packages/linux/; \
		chmod +x offline-packages/linux/zoxide; \
	else \
		echo "  ✓ zoxide already present"; \
	fi

	@# direnv - per-directory environment manager
	@if [ ! -f offline-packages/linux/direnv ] || [ $$(stat -f%z offline-packages/linux/direnv 2>/dev/null || stat -c%s offline-packages/linux/direnv 2>/dev/null) -lt 1000 ]; then \
		echo "  → direnv (environment loader)..."; \
		curl -fsSL "https://github.com/direnv/direnv/releases/download/$(DIRENV_VERSION)/direnv.linux-amd64" \
			-o offline-packages/linux/direnv; \
		chmod +x offline-packages/linux/direnv; \
	else \
		echo "  ✓ direnv already present"; \
	fi

	@# dust - disk usage viewer
	@if [ ! -f offline-packages/linux/dust ] || [ $$(stat -f%z offline-packages/linux/dust 2>/dev/null || stat -c%s offline-packages/linux/dust 2>/dev/null) -lt 1000 ]; then \
		echo "  → dust (disk usage)..."; \
		mkdir -p /tmp/dust-download; \
		curl -fsSL "https://github.com/bootandy/dust/releases/download/$(DUST_VERSION)/dust-$(DUST_VERSION)-x86_64-unknown-linux-gnu.tar.gz" | \
			tar -xz -C /tmp/dust-download --strip-components=1; \
		mv /tmp/dust-download/dust offline-packages/linux/dust; \
		chmod +x offline-packages/linux/dust; \
		rm -rf /tmp/dust-download; \
	else \
		echo "  ✓ dust already present"; \
	fi

	@# gdu - interactive disk usage analyzer
	@if [ ! -f offline-packages/linux/gdu ] || [ $$(stat -f%z offline-packages/linux/gdu 2>/dev/null || stat -c%s offline-packages/linux/gdu 2>/dev/null) -lt 1000 ]; then \
		echo "  → gdu (interactive disk usage)..."; \
		curl -fsSL "https://github.com/dundee/gdu/releases/download/$(GDU_VERSION)/gdu_linux_amd64.tgz" | \
			tar -xz -C /tmp/ && mv /tmp/gdu_linux_amd64 offline-packages/linux/gdu; \
		chmod +x offline-packages/linux/gdu; \
	else \
		echo "  ✓ gdu already present"; \
	fi

	@# mkcert - local HTTPS certificate generator
	@if [ ! -f offline-packages/linux/mkcert ] || [ $$(stat -f%z offline-packages/linux/mkcert 2>/dev/null || stat -c%s offline-packages/linux/mkcert 2>/dev/null) -lt 1000 ]; then \
		echo "  → mkcert (local HTTPS certificates)..."; \
		curl -fsSL "https://github.com/FiloSottile/mkcert/releases/download/$(MKCERT_VERSION)/mkcert-$(MKCERT_VERSION)-linux-amd64" \
			-o offline-packages/linux/mkcert; \
		chmod +x offline-packages/linux/mkcert; \
	else \
		echo "  ✓ mkcert already present"; \
	fi

	@# usbtree - live USB device tree
	@if [ ! -f offline-packages/linux/usbtree ] || [ $$(stat -f%z offline-packages/linux/usbtree 2>/dev/null || stat -c%s offline-packages/linux/usbtree 2>/dev/null) -lt 1000 ]; then \
		echo "  → usbtree (live USB device tree)..."; \
		mkdir -p /tmp/usbtree-download; \
		curl -fsSL "https://github.com/gnomeria/usbtree/releases/download/$(USBTREE_VERSION)/usbtree_$$(echo $(USBTREE_VERSION) | sed 's/^v//')_linux-amd64.tar.gz" | \
			tar -xz -C /tmp/usbtree-download; \
		mv /tmp/usbtree-download/usbtree offline-packages/linux/usbtree; \
		chmod +x offline-packages/linux/usbtree; \
		rm -rf /tmp/usbtree-download; \
	else \
		echo "  ✓ usbtree already present"; \
	fi

	@# gping - ping with a graph
	@if [ ! -f offline-packages/linux/gping ] || [ $$(stat -f%z offline-packages/linux/gping 2>/dev/null || stat -c%s offline-packages/linux/gping 2>/dev/null) -lt 1000 ]; then \
		echo "  → gping (ping with graph)..."; \
		curl -fsSL "https://github.com/orf/gping/releases/download/gping-v$(GPING_VERSION)/gping-Linux-musl-x86_64.tar.gz" | \
			tar -xz -C /tmp/ && mv /tmp/gping offline-packages/linux/gping; \
		chmod +x offline-packages/linux/gping; \
	else \
		echo "  ✓ gping already present"; \
	fi

	@# gopls - Go language server
	@# NOTE: gopls requires Go toolchain to be installed. It cannot be bundled as a standalone binary.
	@# Users who need Go development should install Go separately, then gopls will work automatically.

	@# delta - better git diff
	@if [ ! -f offline-packages/linux/delta ] || [ $$(stat -f%z offline-packages/linux/delta 2>/dev/null || stat -c%s offline-packages/linux/delta 2>/dev/null) -lt 1000 ]; then \
		echo "  → delta (better git diff)..."; \
		mkdir -p /tmp/delta-download; \
		curl -fsSL "https://github.com/dandavison/delta/releases/download/$(DELTA_VERSION)/delta-$(DELTA_VERSION)-x86_64-unknown-linux-musl.tar.gz" | \
			tar -xz -C /tmp/delta-download --strip-components=1; \
		mv /tmp/delta-download/delta offline-packages/linux/delta; \
		chmod +x offline-packages/linux/delta; \
		rm -rf /tmp/delta-download; \
	else \
		echo "  ✓ delta already present"; \
	fi

	@# difftastic - structural diff tool
	@if [ ! -f offline-packages/linux/difft ] || [ $$(stat -f%z offline-packages/linux/difft 2>/dev/null || stat -c%s offline-packages/linux/difft 2>/dev/null) -lt 1000 ]; then \
		echo "  → difftastic (structural diff)..."; \
		curl -fsSL "https://github.com/Wilfred/difftastic/releases/download/$(DIFFTASTIC_VERSION)/difft-x86_64-unknown-linux-gnu.tar.gz" | \
			tar -xz -C offline-packages/linux/; \
		chmod +x offline-packages/linux/difft; \
	else \
		echo "  ✓ difftastic already present"; \
	fi

	@# gum - charm bracelet TUI library
	@if [ ! -f offline-packages/linux/gum ] || [ $$(stat -f%z offline-packages/linux/gum 2>/dev/null || stat -c%s offline-packages/linux/gum 2>/dev/null) -lt 1000 ]; then \
		echo "  → gum (pretty TUI toolkit)..."; \
		curl -fsSL "https://github.com/charmbracelet/gum/releases/download/$(GUM_VERSION)/gum_$$(echo $(GUM_VERSION) | sed 's/^v//')_Linux_x86_64.tar.gz" | \
			tar -xz -C /tmp/ && mv /tmp/gum_$$(echo $(GUM_VERSION) | sed 's/^v//')_Linux_x86_64/gum offline-packages/linux/gum && rm -rf /tmp/gum_*; \
		chmod +x offline-packages/linux/gum; \
	else \
		echo "  ✓ gum already present"; \
	fi

	@# glow - Markdown reader
	@if [ ! -f offline-packages/linux/glow ] || [ $$(stat -f%z offline-packages/linux/glow 2>/dev/null || stat -c%s offline-packages/linux/glow 2>/dev/null) -lt 1000 ]; then \
		echo "  → glow (Markdown reader)..."; \
		tmp_dir=$$(mktemp -d); \
		curl -fsSL "https://github.com/charmbracelet/glow/releases/download/$(GLOW_VERSION)/glow_$$(echo $(GLOW_VERSION) | sed 's/^v//')_Linux_x86_64.tar.gz" | \
			tar -xz -C $$tmp_dir; \
		mv $$tmp_dir/glow_$$(echo $(GLOW_VERSION) | sed 's/^v//')_Linux_x86_64/glow offline-packages/linux/glow; \
		chmod +x offline-packages/linux/glow; \
		rm -rf $$tmp_dir; \
	else \
		echo "  ✓ glow already present"; \
	fi

	@# broot - interactive directory tree navigator
	@if [ ! -f offline-packages/linux/broot ] || [ $$(stat -f%z offline-packages/linux/broot 2>/dev/null || stat -c%s offline-packages/linux/broot 2>/dev/null) -lt 1000 ]; then \
		echo "  → broot (interactive directory navigator)..."; \
		tmp_dir=$$(mktemp -d); \
		curl -fsSL "https://github.com/Canop/broot/releases/download/$(BROOT_VERSION)/broot_$$(echo $(BROOT_VERSION) | sed 's/^v//').zip" -o $$tmp_dir/broot.zip; \
		unzip -p $$tmp_dir/broot.zip x86_64-unknown-linux-musl/broot > offline-packages/linux/broot; \
		chmod +x offline-packages/linux/broot; \
		rm -rf $$tmp_dir; \
	else \
		echo "  ✓ broot already present"; \
	fi

	@# fastfetch - system information tool
	@if [ ! -f offline-packages/linux/fastfetch ] || [ $$(stat -f%z offline-packages/linux/fastfetch 2>/dev/null || stat -c%s offline-packages/linux/fastfetch 2>/dev/null) -lt 1000 ]; then \
		echo "  → fastfetch (system information)..."; \
		tmp_dir=$$(mktemp -d); \
		curl -fsSL "https://github.com/fastfetch-cli/fastfetch/releases/download/$(FASTFETCH_VERSION)/fastfetch-linux-amd64-polyfilled.tar.gz" | \
			tar -xz -C $$tmp_dir; \
		mv $$tmp_dir/fastfetch-linux-amd64-polyfilled/usr/bin/fastfetch offline-packages/linux/fastfetch; \
		chmod +x offline-packages/linux/fastfetch; \
		rm -rf $$tmp_dir; \
	else \
		echo "  ✓ fastfetch already present"; \
	fi

	@# airgap-dev-kit - CLI wrapper command
	@echo "  → airgap-dev-kit (CLI wrapper)..."; \
	cp scripts/airgap-dev-kit offline-packages/linux/airgap-dev-kit; \
	chmod +x offline-packages/linux/airgap-dev-kit

	@# lazygit - Terminal UI for git
	@if [ ! -f offline-packages/linux/lazygit ]; then \
		echo "  → lazygit (git TUI)..."; \
		curl -fsSL "https://github.com/jesseduffield/lazygit/releases/download/v0.43.1/lazygit_0.43.1_Linux_x86_64.tar.gz" \
			| tar -xz -C offline-packages/linux/ lazygit; \
		chmod +x offline-packages/linux/lazygit; \
	else \
		echo "  ✓ lazygit already present"; \
	fi

	@# jq - JSON processor
	@if [ ! -f offline-packages/linux/jq ]; then \
		echo "  → jq (JSON processor)..."; \
		curl -fsSL "https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-linux-amd64" \
			-o offline-packages/linux/jq; \
		chmod +x offline-packages/linux/jq; \
	else \
		echo "  ✓ jq already present"; \
	fi

	@# svu - semantic version utility
	@if [ ! -f offline-packages/linux/svu ]; then \
		echo "  → svu (semantic version utility)..."; \
		tmp_dir=$$(mktemp -d); \
		curl -fsSL "https://github.com/caarlos0/svu/releases/download/v$(SVU_VERSION)/svu_$(SVU_VERSION)_linux_amd64.tar.gz" | \
			tar -xz -C $$tmp_dir; \
		mv $$tmp_dir/svu offline-packages/linux/svu; \
		chmod +x offline-packages/linux/svu; \
		rm -rf $$tmp_dir; \
	else \
		echo "  ✓ svu already present"; \
	fi

	@# gopls: not bundled - requires 'go install golang.org/x/tools/gopls@latest'

	@# lua-language-server - Lua LSP
	@if [ ! -f offline-packages/linux/lua-language-server ]; then \
		echo "  → lua-language-server (Lua LSP)..."; \
		mkdir -p /tmp/lua-ls-download; \
		curl -fsSL "https://github.com/LuaLS/lua-language-server/releases/download/3.10.5/lua-language-server-3.10.5-linux-x64.tar.gz" \
			| tar -xz -C /tmp/lua-ls-download; \
		mv /tmp/lua-ls-download/bin/lua-language-server offline-packages/linux/; \
		chmod +x offline-packages/linux/lua-language-server; \
		rm -rf /tmp/lua-ls-download; \
	else \
		echo "  ✓ lua-language-server already present"; \
	fi


	@# shellcheck - Shell script linter/analyzer
	@if [ ! -f offline-packages/linux/shellcheck ]; then \
		echo "  → shellcheck (Shell linter)..."; \
		mkdir -p /tmp/shellcheck-download; \
		curl -fsSL "https://github.com/koalaman/shellcheck/releases/download/v0.10.0/shellcheck-v0.10.0.linux.x86_64.tar.xz" \
			| tar -xJ -C /tmp/shellcheck-download --strip-components=1; \
		mv /tmp/shellcheck-download/shellcheck offline-packages/linux/; \
		chmod +x offline-packages/linux/shellcheck; \
		rm -rf /tmp/shellcheck-download; \
	else \
		echo "  ✓ shellcheck already present"; \
	fi

update-fonts:
	@echo "Checking fonts..."
	@mkdir -p fonts
	@if [ ! -f fonts/JetBrainsMono.zip ] || [ $$(stat -f%z fonts/JetBrainsMono.zip 2>/dev/null || stat -c%s fonts/JetBrainsMono.zip 2>/dev/null) -lt 1000000 ]; then \
		echo "  → JetBrainsMono Nerd Font..."; \
		curl -fsSL "https://github.com/ryanoasis/nerd-fonts/releases/download/$(NERD_FONT_VERSION)/JetBrainsMono.zip" \
			-o fonts/JetBrainsMono.zip; \
	else \
		echo "  ✓ JetBrainsMono Nerd Font already present"; \
	fi

verify:
	@./scripts/verify-packages.sh

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
	@# Ship the full kit so the air-gapped machine has Makefile, scripts, docs, etc.
	@# Exclude only build artifacts and VCS/tool-specific dirs.
	@COPYFILE_DISABLE=1 tar --no-xattrs \
		--exclude='.git' --exclude='.claude' --exclude='.devin' --exclude='._*' \
		--exclude='.github' --exclude='test' \
		--exclude='nvim-linux-x86_64' --exclude='nvim-linux64' \
		-czf airgap-dev-kit.tar.gz \
		install.sh uninstall.sh Makefile VERSION \
		README.md CHANGES.md CLAUDE.md \
		STOW-BUNDLING.md INSTALLATION-TRACKING.md QUICK-START-FIXES.md TESTING.md \
		check-neovim.sh install-mason-lsp.sh \
		scripts/ docs/ \
		offline-packages/linux/ \
		$$( [ -f offline-packages/lazy-plugins.tar.gz ] && echo offline-packages/lazy-plugins.tar.gz ) \
		$$( [ -f offline-packages/mason-lsp.tar.gz ] && echo offline-packages/mason-lsp.tar.gz ) \
		config/ \
		$$( [ -d fonts ] && echo fonts/ )
	@echo ""
	@ls -lh airgap-dev-kit.tar.gz
	@echo ""
	@echo "✓ Package ready for deployment!"
	@echo "  Transfer airgap-dev-kit.tar.gz to target machine"
	@echo "  Extract: mkdir airgap-dev-kit && tar -xzf airgap-dev-kit.tar.gz -C airgap-dev-kit"
	@echo "  Install: cd airgap-dev-kit && ./install.sh"
	@rm -f VERSION

download-release:
	@./scripts/release-update.sh download --dir "$(RELEASE_DIR)"

airgap:
	@GOCACHE="$${GOCACHE:-/tmp/airgap-dev-kit-gocache}" GOMODCACHE="$${GOMODCACHE:-/tmp/airgap-dev-kit-gomodcache}" go build -trimpath -ldflags='-s -w' -o airgap ./main.go

package-v2:
	@test -n "$(BINARY)" || (echo "Set BINARY to the prebuilt Linux amd64 airgap binary" >&2; exit 2)
	@sh scripts/package-v2.sh --binary "$(BINARY)" --flavor "$(FLAVOR)" --output "$(OUTPUT)"

package-cli: version-file
	@echo "Creating CLI-only deployment package..."
	@$(MAKE) --no-print-directory verify
	@echo ""
	@echo "Building tarball: airgap-dev-kit-cli.tar.gz"
	@find .package-cli-staging -name '._*' -type f -delete 2>/dev/null || true
	@rm -rf .package-cli-staging
	@mkdir -p .package-cli-staging/airgap-dev-kit/offline-packages
	@touch .package-cli-staging/airgap-dev-kit/.airgap-cli-only
	@COPYFILE_DISABLE=1 cp install.sh uninstall.sh Makefile VERSION README.md CHANGES.md CLAUDE.md \
		STOW-BUNDLING.md INSTALLATION-TRACKING.md QUICK-START-FIXES.md TESTING.md \
		check-neovim.sh install-mason-lsp.sh \
		.package-cli-staging/airgap-dev-kit/
	@COPYFILE_DISABLE=1 cp -R scripts docs config .package-cli-staging/airgap-dev-kit/
	@COPYFILE_DISABLE=1 cp -R offline-packages/linux .package-cli-staging/airgap-dev-kit/offline-packages/
	@if [ -f offline-packages/lazy-plugins.tar.gz ]; then \
		cp offline-packages/lazy-plugins.tar.gz .package-cli-staging/airgap-dev-kit/offline-packages/; \
	fi
	@if [ -f offline-packages/mason-lsp.tar.gz ]; then \
		cp offline-packages/mason-lsp.tar.gz .package-cli-staging/airgap-dev-kit/offline-packages/; \
	fi
	@rm -f .package-cli-staging/airgap-dev-kit/offline-packages/linux/wezterm.AppImage
	@COPYFILE_DISABLE=1 tar --no-xattrs \
		--exclude='.git' --exclude='.claude' --exclude='.devin' --exclude='._*' \
		--exclude='.github' --exclude='test' \
		--exclude='fonts' \
		--exclude='offline-packages/linux/wezterm.AppImage' \
		--exclude='nvim-linux-x86_64' --exclude='nvim-linux64' \
		-czf airgap-dev-kit-cli.tar.gz -C .package-cli-staging airgap-dev-kit
	@rm -rf .package-cli-staging
	@rm -f VERSION
	@echo ""
	@ls -lh airgap-dev-kit-cli.tar.gz
	@echo ""
	@echo "✓ CLI-only package ready for deployment!"
	@echo "  Transfer airgap-dev-kit-cli.tar.gz to target machine"
	@echo "  Extract: mkdir airgap-dev-kit && tar -xzf airgap-dev-kit-cli.tar.gz -C airgap-dev-kit"
	@echo "  Install: cd airgap-dev-kit && ./install.sh"

package-with-config: verify version-file
	@echo "Creating full deployment package (with config/)..."
	@if [ ! -d config ]; then \
		echo "Warning: config/ directory not found. Creating placeholder..."; \
		mkdir -p config/.config; \
		echo "# Add your dotfiles here for GNU Stow" > config/README.md; \
	fi
	@COPYFILE_DISABLE=1 tar --no-xattrs \
		--exclude='.git' --exclude='.claude' --exclude='.devin' --exclude='._*' \
		--exclude='.github' --exclude='test' \
		--exclude='nvim-linux-x86_64' --exclude='nvim-linux64' \
		-czf airgap-dev-kit-full.tar.gz \
		install.sh uninstall.sh Makefile VERSION \
		README.md CHANGES.md CLAUDE.md \
		STOW-BUNDLING.md INSTALLATION-TRACKING.md QUICK-START-FIXES.md TESTING.md \
		check-neovim.sh install-mason-lsp.sh \
		scripts/ docs/ \
		offline-packages/linux/ \
		$$( [ -f offline-packages/lazy-plugins.tar.gz ] && echo offline-packages/lazy-plugins.tar.gz ) \
		$$( [ -f offline-packages/mason-lsp.tar.gz ] && echo offline-packages/mason-lsp.tar.gz ) \
		fonts/ \
		config/
	@ls -lh airgap-dev-kit-full.tar.gz
	@echo ""
	@echo "✓ Full package ready (includes config/)!"
	@rm -f VERSION

docker-test: package
	@bash scripts/docker-smoke-test airgap-dev-kit.tar.gz

test-cli-package:
	@bash test/scripts/test-nvim-config-syntax.sh
	@bash test/scripts/test-install-dry-run.sh
	@bash test/scripts/test-cli-only-package.sh
	@bash test/scripts/test-busy-binary-replace.sh
	@bash test/scripts/test-config-idempotent.sh
	@bash test/scripts/test-nvim-state-safety.sh
	@bash test/scripts/test-starship-init-last.sh

test-update-tools:
	@bash test/scripts/test-release-update.sh
	@bash test/scripts/test-check-updates-json.sh
	@bash test/scripts/test-close-superseded-update-prs.sh

install:
	@echo "Installing Linux air-gap dev kit on current machine..."
	@chmod +x install.sh
	@./install.sh

check-updates:
	@echo "Checking for newer tool releases..."
	@bash scripts/check-updates.sh

check-updates-strict:
	@echo "Checking for newer tool releases..."
	@bash scripts/check-updates.sh --fail-on-outdated

clean:
	@echo "Removing downloaded binaries (keeping placeholders)..."
	@find offline-packages -type f -size +1M -delete
	@echo "✓ Large binaries removed. Run 'make update' to re-download."

clean-all: clean
	@echo "Removing package tarballs..."
	@rm -f airgap-dev-kit.tar.gz airgap-dev-kit-cli.tar.gz airgap-dev-kit-full.tar.gz
	@echo "✓ All generated files removed."

sync-nvim-config:
	@echo "Syncing local Neovim config to repo..."
	@if [ ! -d ~/.config/nvim ]; then \
		echo "Error: ~/.config/nvim not found!"; \
		echo "Please set up your Neovim config first."; \
		exit 1; \
	fi
	@rm -rf config/nvim/.config/nvim
	@mkdir -p config/nvim/.config
	@cp -r ~/.config/nvim config/nvim/.config/nvim
	@echo "✓ Neovim config synced from ~/.config/nvim to config/nvim/.config/nvim"
	@echo ""
	@echo "Files synced:"
	@ls -lah config/nvim/.config/nvim/
	@echo ""
	@echo "Don't forget to commit: git add config/nvim && git commit -m 'Update Neovim config'"

# Sync the repo to a remote host for local testing.
# Override with: make sync REMOTE=user@host DEST=/path/to/dir
REMOTE ?= jstein@ai
DEST   ?= ~/airgap-dev-kit
sync:
	@echo "Syncing repo to $(REMOTE):$(DEST)..."
	@rsync --archive --compress --partial --delete \
		--exclude='.git/' \
		--exclude='*.tar.gz' \
		--exclude='offline-packages/linux/*.AppImage' \
		--exclude='offline-packages/linux/nvim-linux64/' \
		--exclude='.claude/' \
		--exclude='.devin/' \
		./ "$(REMOTE):$(DEST)"
	@echo "✓ Synced to $(REMOTE):$(DEST)"
	@echo "  SSH in and run: cd ~/airgap-dev-kit && ./install.sh"
