# `mise-nix`

A [Mise](https://github.com/jdx/mise) plugin that brings the power of the [Nix](https://nixos.org/) ecosystem to your development workflow.

## Features

- 🚀 **100,000+ packages** from nixpkgs
- 📦 **VSCode extensions** support

## Prerequisites

* **[Mise](https://github.com/jdx/mise)** v2025.7.8+
* **[Nix](https://nixos.org/)**

## Installation

```sh
mise plugin install nix https://github.com/jbadeau/mise-nix.git
```

## Quick Start

```sh
# List available versions
mise ls-remote nix:hello

# Install version
mise install nix:hello@2.12.1
```

## Usage

### Standard Packages (Recommended)

Uses nixhub.io for pre-built, cached packages:

```sh
# Latest version
mise install nix:hello

# Specific version
mise install nix:hello@2.12.1

# Version aliases
mise install nix:hello@stable
```

### Flake References

```sh
# GitHub
mise install "nix:hello@github+nixos/nixpkgs"
mise install "nix:hello@nixos/nixpkgs#hello"

# GitLab
mise install "nix:mytool@gitlab+group/project"

# Git URLs
mise install "nix:hello@git+https://github.com/nixos/nixpkgs.git"
```

### Local Flakes

```sh
export MISE_NIX_ALLOW_LOCAL_FLAKES=true
mise install "nix:mytool@./my-project"
```

### VSCode Extensions

```sh
mise install "nix:vscode+install=vscode-extensions.golang.go"
```

## Limitations

Use `github+` instead of `github:` due to mise parsing limitations.

## Configuration

Environment variables:

```sh
export MISE_NIX_ALLOW_LOCAL_FLAKES=true  # Enable local flakes
export MISE_NIX_NIXHUB_BASE_URL="https://custom.nixhub.io"  # Custom nixhub
```

## Nix Setup

Add to `~/.config/nix/nix.conf`:

```ini
experimental-features = nix-command flakes
substituters = https://cache.nixos.org https://nix-community.cachix.org
trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= nix-community.cachix.org-1:0VI8sF6Vsp2Jxw8+OFeVfYVdIY7X+GTtY+lR78QAbXs=
```

## Development

```sh
# Setup
mise init # Install and link

# Tests
mise test # Unit tests
mise e2e  # Integration tests
```