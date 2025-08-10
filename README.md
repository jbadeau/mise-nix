# `mise-nix`

`mise-nix` is a backend plugin for [Mise](https://github.com/jdx/mise) that allows you to install and manage packages using [Nix](https://nixos.org/).

## Why use this plugin?

- 🚀 Access to over 100,000 packages
- ⚡ Better Nix developer experience
- 📦 Install VSCode extensions

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

## Complete Usage Guide

### Standard Nixpkgs Packages (Recommended - Fast & Cached)

Uses nixhub.io for pre-built, cached packages:

```sh
# Latest version
mise install nix:hello

# Specific version
mise install nix:hello@2.12.1

# Version aliases
mise install nix:hello@stable
```

### GitHub Sources

Uses GitHub shorthand for fast access:

```sh
# From nixpkgs GitHub repository (default branch)
mise install "nix:hello@github+nixos/nixpkgs"

# From specific branch
mise install "nix:hello@github+nixos/nixpkgs/nixos-unstable"

# From specific release/tag
mise install "nix:hello@github+nixos/nixpkgs?ref=23.11"

# From specific commit SHA
mise install "nix:hello@github+nixos/nixpkgs/abc123def456"

# With revision parameter
mise install "nix:hello@github+nixos/nixpkgs?rev=abc123def456"

# With subdirectory (flake in subdirectory)
mise install "nix:mytool@github+company/monorepo/main?dir=packages/tool"

# GitHub shorthand syntax (alternative)
mise install "nix:hello@nixos/nixpkgs#hello"
```

### GitLab Sources

Uses GitLab shorthand:

```sh
# From GitLab repository
mise install "nix:mytool@gitlab+group/project"
```

### Raw Git Sources

Uses full Git URLs for maximum compatibility:

```sh
# From raw git URL
mise install "nix:hello@git+https://github.com/nixos/nixpkgs.git"
```

### Local Flakes (Experimental)

⚠️ **Experimental Feature**: Local flake support is experimental and subject to change.

For development with local Nix flakes:

```sh
export MISE_NIX_ALLOW_LOCAL_FLAKES=true

# Local development
mise install "nix:mytool@./my-project"
```

### VSCode Extensions (Experimental)

Install VSCode extensions using vscode+install syntax:

```sh
mise install "nix:vscode+install=vscode-extensions.golang.go"
```

## Known Limitations

Due to mise's argument parsing limitations, some Git URL formats require workarounds:

### Git Hosting Shorthand Limitations

```sh
# ❌ Not supported (direct prefixes with colons)
mise install nix:hello@github:nixos/nixpkgs#hello
mise install nix:mytool@gitlab:group/project#default

# ✅ Use these workarounds instead
mise install "nix:hello@github+nixos/nixpkgs"
mise install "nix:mytool@gitlab+group/project"
```

### Git URL Workarounds

Mise rejects `git+ssh://` and `git+https://` as invalid prefixes, so use these alternatives:

| Prefix | Converts To | Use Case |
|--------|-------------|----------|
| `ssh+git@host/repo.git` | `git+ssh://git@host/repo.git` | SSH access |
| `https+user:token@host/repo.git` | `git+https://user:token@host/repo.git` | HTTPS auth |

```sh
# ❌ These don't work due to mise parsing
mise install "nix:hello@git+ssh://git@github.com/nixos/nixpkgs.git"
mise install "nix:hello@git+https://user:token@github.com/nixos/nixpkgs.git"

# ✅ Use these workarounds instead
mise install "nix:hello@ssh+git@github.com/nixos/nixpkgs.git"
mise install "nix:hello@https+user:token@github.com/nixos/nixpkgs.git"
```

## Settings

```sh
# Custom NixHub instance
export MISE_NIX_NIXHUB_BASE_URL="https://custom-nixhub.example.com"

# Custom NixPkgs repository
export MISE_NIX_NIXPKGS_REPO_URL="https://github.com/custom/nixpkgs"

# Enable local flakes (security risk)
export MISE_NIX_ALLOW_LOCAL_FLAKES=true

# Enterprise Git instances
export MISE_NIX_GITHUB_ENTERPRISE_URL="github.company.com"
export MISE_NIX_GITLAB_ENTERPRISE_URL="gitlab.company.com"
```

## Nix Configuration

**Important:** Add to `~/.config/nix/nix.conf` for optimal performance:

```ini
experimental-features = nix-command flakes
substituters = https://cache.nixos.org https://nix-community.cachix.org
trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= nix-community.cachix.org-1:0VI8sF6Vsp2Jxw8+OFeVfYVdIY7X+GTtY+lR78QAbXs=
```

Without this configuration, package installations will be significantly slower as Nix will build from source instead of using pre-built binaries.

## Troubleshooting

**"Package not found"**: Check package exists on [NixHub](https://www.nixhub.io)

**"Invalid prefix"**: Use `github+` syntax instead of direct `github:`

**"Local flakes disabled"**: Set `MISE_NIX_ALLOW_LOCAL_FLAKES=true`

**Build failures**: Ensure Nix experimental features are enabled

**Slow installs**: Avoid full git URLs for large repositories

**VSCode extensions not showing**: Restart VSCode after installing extensions

## Development

```sh
# Setup
mise init # Install and link

# Tests
mise test # Unit tests
mise e2e  # Integration tests
```