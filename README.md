# `mise-nix`

`mise-nix` is a backend plugin for [Mise](https://github.com/jdx/mise) that allows you to install and manage packages using [Nix](https://nixos.org/).

## Why use this plugin?

- **Reproducible environments**: Pin tools to exact versions with Nix's deterministic builds
- **Massive package selection**: Access to 100,000+ Nix packages
- **Cross-platform consistency**: Same tools and versions across Linux, macOS, and other platforms
- **Private repository support**: Install tools from your company's private Git repositories

## Prerequisites

* **[Mise](https://github.com/jdx/mise)** v2025.7.8+
* **[Nix](https://nixos.org/)** with experimental features enabled

## Installation

```sh
mise plugin install nix https://github.com/jbadeau/mise-nix.git
```

## Quick Start

```sh
# NixHub packages (recommended)
mise install nix:helmfile@1.1.2
mise exec nix:helmfile@1.1.2 -- helmfile version

# Flake references  
mise install nix:hello@nixos/nixpkgs#hello
mise exec nix:hello@nixos/nixpkgs#hello -- hello

# List versions
mise ls-remote nix:helmfile
```

## Usage Patterns

### 1. NixHub Packages (Recommended)

Curated packages with version history:

```sh
mise install nix:helmfile@1.1.2     # Specific version
mise install nix:helmfile@stable    # Latest stable
mise install nix:helmfile           # Latest
```

### 2. Flake References (Experimental)

Direct access to Nix flakes:

```sh
# GitHub shorthand
mise install nix:hello@nixos/nixpkgs#hello

# Community overlays
mise install nix:emacs@nix-community/emacs-overlay#emacs-git
```

### 3. Private Repositories (Experimental)

Custom prefixes for private repos:

```sh
# GitHub/GitLab shorthand
mise install "nix:tool@gh-company/repo#tool"
mise install "nix:tool@gl-group/project#tool"

# Full URLs
mise install "nix:tool@ssh-git@gitlab.company.com/repo.git#tool"
mise install "nix:tool@https-user:token@github.com/repo.git#tool"
```

### 4. Local Flakes (Experimental)

```sh
export MISE_NIX_ALLOW_LOCAL_FLAKES=true
mise install "nix:package@./my-flake#package"
```

## Nix Configuration

Add to `~/.config/nix/nix.conf`:

```ini
experimental-features = nix-command flakes
substituters = https://cache.nixos.org https://nix-community.cachix.org
trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= nix-community.cachix.org-1:0VI8sF6Vsp2Jxw8+OFeVfYVdIY7X+GTtY+lR78QAbXs=
```

## Custom Git Prefixes

| Prefix | Converts To | Use Case |
|--------|-------------|----------|
| `gh-user/repo` | `github:user/repo` | Private GitHub repos |
| `gl-group/project` | `gitlab:group/project` | Private GitLab repos |
| `ssh-git@host/repo.git` | `git+ssh://git@host/repo.git` | SSH access |
| `https-user:token@host/repo.git` | `git+https://user:token@host/repo.git` | HTTPS auth |

## Known Limitations

Due to mise's argument parsing:

```sh
# ❌ Not supported
mise install nix:hello@github:nixos/nixpkgs#hello

# ✅ Use instead
mise install nix:hello@nixos/nixpkgs#hello
mise install "nix:hello@gh-nixos/nixpkgs#hello"
```

## Environment Variables

```sh
# Custom NixHub instance
export MISE_NIX_NIXHUB_BASE_URL="https://custom-nixhub.example.com"

# Enable local flakes (security risk)
export MISE_NIX_ALLOW_LOCAL_FLAKES=true

# Enterprise Git instances
export MISE_NIX_GITHUB_ENTERPRISE_URL="github.company.com"
export MISE_NIX_GITLAB_URL="gitlab.company.com"
```

## Performance Notes

**⚠️ Warning**: Avoid full git URLs for large repos like nixpkgs (>1GB). Use GitHub shorthand instead:

```sh
# ❌ Slow (clones entire repo)
mise install "nix:hello@https-github.com/nixos/nixpkgs.git#hello"

# ✅ Fast (optimized fetching)
mise install nix:hello@nixos/nixpkgs#hello
```

## Troubleshooting

**"Tool not found"**: Check package exists on [NixHub](https://www.nixhub.io)

**"Invalid prefix"**: Use custom prefixes like `gh-` instead of `github:`

**"Local flakes disabled"**: Set `MISE_NIX_ALLOW_LOCAL_FLAKES=true`

**Build failures**: Ensure Nix experimental features are enabled

**Slow installs**: Avoid full git URLs for large repositories

## Development

```sh
# Run tests
mise test     # Unit tests
mise e2e      # Integration tests
```

The test suite covers NixHub packages, flake references, custom prefixes, and security features.