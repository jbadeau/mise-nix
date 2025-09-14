FROM ghcr.io/xtruder/nix-devcontainer:latest

# Install required packages:
# - glibc.bin: includes getconf required by VSCode Server
# - coreutils: basic Unix utilities
# - zip: required for creating VSIX packages for VSCode extensions
RUN nix-env -iA nixpkgs.glibc.bin && \
    nix-env -iA nixpkgs.coreutils && \
    nix-env -iA nixpkgs.zip && \
    nix-env -iA nixpkgs.unzip

# Ensure the tools are in PATH
ENV PATH="/nix/var/nix/profiles/default/bin:${PATH}"