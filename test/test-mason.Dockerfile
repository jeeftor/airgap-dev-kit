FROM  ubuntu:24.04

# Install build dependencies for Neovim
RUN apt-get update && \
    apt-get install -y \
    # Basic system dependencies
    curl \
    git \
    build-essential \
    tar \
    gzip \
    wget \
    software-properties-common \
    ca-certificates \
    # Mason/LazyVim prerequisites
    ripgrep \
    fd-find \
    fzf \
    tree-sitter-cli \
    # Neovim and runtime dependencies
    neovim \
    python3-neovim \
    nodejs \
    npm

# Install build dependencies (layer 2 - can change)
RUN apt-get install -y \
    cmake \
    ninja-build \
    gettext \
    libtool \
    libtool-bin \
    autoconf \
    automake \
    pkg-config \
    unzip 

# Install certificates (layer 3 - rarely changes)
RUN curl -ksSL https://gitlab.mitre.org/mitre-scripts/mitre-pki/raw/master/os_scripts/install_certs.sh | sh

# RUN rm -rf /var/lib/apt/lists/*

# Install lazygit from GitHub releases (x86_64 version)
RUN LAZYGIT_VERSION="0.40.2" && \
    cd /tmp && \
    wget -q https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz && \
    tar xzf lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz && \
    mv lazygit /usr/local/bin/ && \
    chmod +x /usr/local/bin/lazygit && \
    rm -rf /tmp/lazygit*

# Build Neovim from source (LazyVim compatible version)
RUN cd /tmp && \
    git clone https://github.com/neovim/neovim.git 
RUN cd /tmp/neovim && \
    git checkout v0.11.2 
RUN  cd /tmp/neovim  && make CMAKE_BUILD_TYPE=RelWithDebInfo 

RUN cd /tmp/neovim  && make install && \
    echo "✓ Built Neovim v0.11.2 from source (LazyVim compatible)" && \
    rm -rf /tmp/neovim

# Create working directory
WORKDIR /workspace

# Copy DRY system files
COPY config/plugin-manifest.lua /workspace/config/
COPY scripts/install-from-manifest.sh /workspace/scripts/
COPY test/test-with-manifest.sh /workspace/test/
RUN chmod +x /workspace/scripts/install-from-manifest.sh && \
    chmod +x /workspace/test/test-with-manifest.sh

# Verify installations and create symlinks (layer 4 - can change)
RUN nvim --version && \
    echo "✓ Neovim v0.11.2 built from source (LazyVim compatible)" && \
    ln -sf /usr/bin/fdfind /usr/local/bin/fd && \
    lazygit --version

# Install Rust and tree-sitter-cli via rustup (lightweight layer)
# RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && \
#     . ~/.cargo/env && \
#     cargo install tree-sitter-cli --locked --version 0.24.7 && \
#     echo "✓ Installed tree-sitter-cli v0.24.7 via cargo" && \
#     tree-sitter --version
# RUN tree-sitter init-config    

# Set up a test script that will be mounted
CMD ["/bin/bash"]