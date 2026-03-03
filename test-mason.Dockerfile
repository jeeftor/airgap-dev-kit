# Docker environment for testing Mason LSP installations
FROM ubuntu:22.04

# Install minimal dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    build-essential \
    tar \
    gzip \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Create working directory
WORKDIR /workspace

# Copy your static Neovim binary (or download it)
# We'll download it fresh to match GitHub Actions
RUN curl -fL "https://github.com/jeeftor/static-neovim/releases/latest/download/nvim-static-x86_64" \
    -o /usr/local/bin/nvim && \
    chmod +x /usr/local/bin/nvim

# Verify Neovim works
RUN nvim --version

# Set up a test script that will be mounted
CMD ["/bin/bash"]
