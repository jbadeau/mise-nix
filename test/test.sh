#!/bin/bash
set -e

echo "Testing plugin functionality..."

# Test basic functionality
if [[ "$(mise ls-remote nix:helmfile)" == "" ]]; then
    echo "ERROR: No versions available"
    exit 1
fi

mise install nix:helmfile
mise exec nix:helmfile -- helmfile version
mise uninstall nix:helmfile

# Test version
mise install nix:helmfile@1.1.2
mise exec nix:helmfile@1.1.2 -- helmfile version
mise uninstall nix:helmfile@1.1.2

# Test stable
mise install nix:helmfile@stable
mise exec nix:helmfile@stable -- helmfile version
mise uninstall nix:helmfile@stable

# Test latest
mise install nix:helmfile@latest
mise exec nix:helmfile@latest -- helmfile version
mise uninstall nix:helmfile@latest

echo "All tests passed!"