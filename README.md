# `mise-nix`

A [Mise](https://github.com/jdx/mise) plugin that brings the power of the [Nix](https://nixos.org/) ecosystem to your development workflow.

## Features

- 🚀 **100,000+ packages** from nixpkgs
- 🔌 **VSCode extensions** support
- 🔌 **JetBrains plugins** support
- 🔌 **Neovim plugins** support

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

# GitHub with outputs out,dev
mise install "nix:enchant@nixos/nixpkgs#enchant^out,dev"

# GitLab
mise install "nix:mytool@gitlab+group/project"

# Git HTTPS URLs
mise install "nix:hello@https+github.com/nixos/nixpkgs.git#hello"

# Git SSH URLs
mise install "nix:mytool@ssh+git@github.com/owner/repo.git#default"
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

### Neovim Plugins

Install Neovim plugins from nixpkgs `vimPlugins`:

```sh
# Install nvim-treesitter
mise install "nix:neovim+install=vimPlugins.nvim-treesitter"

# Install plenary.nvim (common dependency)
mise install "nix:neovim+install=vimPlugins.plenary-nvim"

# Install telescope.nvim
mise install "nix:neovim+install=vimPlugins.telescope-nvim"
```

Plugins are automatically symlinked to `~/.local/share/nvim/site/pack/nix/start/` and will be auto-loaded by Neovim on startup.

**Notes:**
- No `init.lua` configuration needed - plugins auto-load via Neovim's native `:h packages` mechanism
- Uses a separate `nix` pack namespace - compatible with lazy.nvim, packer.nvim, etc.
- Respects `XDG_DATA_HOME` if set

### JetBrains Plugins

Install plugins from the [nix-jetbrains-plugins](https://github.com/theCapypara/nix-jetbrains-plugins) repository:

```sh
# Install File Watchers plugin for IntelliJ IDEA Ultimate (Linux)
mise install "nix:jetbrains+install=jetbrains-plugins.x86_64-linux.idea-ultimate.2024.3.com.intellij.plugins.watcher"

# Install File Watchers plugin for IntelliJ IDEA Ultimate (macOS)
mise install "nix:jetbrains+install=jetbrains-plugins.aarch64-darwin.idea-ultimate.2024.3.com.intellij.plugins.watcher"

# Install GitToolBox for GoLand
mise install "nix:jetbrains+install=jetbrains-plugins.x86_64-linux.goland.2024.3.zielu.gittoolbox"

# Install Database Tools for WebStorm
mise install "nix:jetbrains+install=jetbrains-plugins.x86_64-linux.webstorm.2024.3.com.intellij.database"
```

The plugin will be automatically extracted to the correct JetBrains IDE plugin directory. Restart your IDE to activate the installed plugins.

**Notes:**
- The system architecture (e.g., `x86_64-linux`, `aarch64-darwin`) must match your current system
- Plugins are built directly from the nix-jetbrains-plugins flake repository without querying nixhub
- You can find plugin IDs at the bottom of JetBrains Marketplace pages

### Unfree Packages

Some packages (e.g. Discord) are marked as unfree in nixpkgs. To install them:

```sh
# Using MISE_NIX env var (recommended - auto-sets NIXPKGS_ALLOW_UNFREE)
export MISE_NIX_ALLOW_UNFREE=true
mise install nix:discord

# Or using native Nix env var directly
export NIXPKGS_ALLOW_UNFREE=1
mise install nix:discord
```

### Insecure Packages

Some packages with known vulnerabilities require explicit opt-in:

```sh
# Using MISE_NIX env var (recommended - auto-sets NIXPKGS_ALLOW_INSECURE)
export MISE_NIX_ALLOW_INSECURE=true
mise install nix:some-package

# Or using native Nix env var directly
export NIXPKGS_ALLOW_INSECURE=1
mise install nix:some-package
```

## Limitations

Mise rejects colons (`:`) in version strings. Use these workaround prefixes:

| Instead of | Use |
|------------|-----|
| `github:owner/repo` | `github+owner/repo` |
| `gitlab:group/project` | `gitlab+group/project` |
| `git+https://host/repo.git` | `https+host/repo.git` |
| `git+ssh://git@host/repo.git` | `ssh+git@host/repo.git` |

## Configuration

Environment variables can be used to configure this plugin:

| Variable | Description |
|----------|-------------|
| `MISE_NIX_ALLOW_UNFREE` | Set to `true` to allow unfree packages (auto-sets `NIXPKGS_ALLOW_UNFREE=1`) |
| `MISE_NIX_ALLOW_INSECURE` | Set to `true` to allow insecure packages (auto-sets `NIXPKGS_ALLOW_INSECURE=1`) |
| `MISE_NIX_ALLOW_LOCAL_FLAKES` | Set to `true` to enable local flake references |
| `MISE_NIX_NIXHUB_BASE_URL` | Custom nixhub.io URL |
| `MISE_NIX_NIXPKGS_REPO_URL` | Custom nixpkgs repository URL |

Native Nix env vars are also supported:

| Variable | Description |
|----------|-------------|
| `NIXPKGS_ALLOW_UNFREE` | Set to `1` to allow unfree packages (enables `--impure`) |
| `NIXPKGS_ALLOW_INSECURE` | Set to `1` to allow insecure packages (enables `--impure`) |

## Nix Setup

Add to `~/.config/nix/nix.conf`:

```ini
experimental-features = nix-command flakes
substituters = https://cache.nixos.org https://nix-community.cachix.org
trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= nix-community.cachix.org-1:0VI8sF6Vsp2Jxw8+OFeVfYVdIY7X+GTtY+lR78QAbXs=
```

## Development

### Setup and Tests

Install Lua via brew (asdf plugin has a bug with LuaRocks 3.13.0):

```sh
brew install lua luarocks
```

```sh
mise init  # Link the plugin
mise test  # Unit tests
mise e2e   # Integration tests
```
