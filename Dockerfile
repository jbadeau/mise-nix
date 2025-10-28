# Dockerfile for running e2e tests in a hermetic container environment
FROM ghcr.io/xtruder/nix-devcontainer:latest

# Install required system packages
RUN nix-env -iA nixpkgs.glibc.bin && \
    nix-env -iA nixpkgs.coreutils && \
    nix-env -iA nixpkgs.zip && \
    nix-env -iA nixpkgs.unzip && \
    nix-env -iA nixpkgs.git && \
    nix-env -iA nixpkgs.curl && \
    nix-env -iA nixpkgs.bash

# Ensure tools are in PATH
ENV PATH="/nix/var/nix/profiles/default/bin:${PATH}"

# Install mise
RUN curl https://mise.run | sh && \
    chmod +x /home/code/.local/bin/mise

# Add mise to PATH
ENV PATH="/home/code/.local/bin:${PATH}"

# Set up working directory
WORKDIR /workspace

# Copy project files (needed for plugin linking)
COPY . .

# Trust the mise config and link the local nix plugin
RUN /home/code/.local/bin/mise trust && \
    /home/code/.local/bin/mise settings set experimental true && \
    /home/code/.local/bin/mise plugin link nix /workspace --force

# Install shellspec for running e2e tests
RUN /home/code/.local/bin/mise install nix:shellspec@latest && \
    /home/code/.local/bin/mise use -g nix:shellspec@latest

# Set environment variables for mise
ENV MISE_QUIET=true
ENV MISE_LOG_LEVEL=error

# Default command runs the e2e tests using mise exec
# This avoids installing other tools from mise.toml
CMD ["mise", "exec", "nix:shellspec@latest", "--", "shellspec"]
