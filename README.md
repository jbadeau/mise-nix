# `mise-nix`

`mise-nix` is a backend plugin for [Mise](https://github.com/jdx/mise) that allows you to install and manage
packages using [Nix](https://nixos.org/).

## Why use this plugin?

This plugin bridges the gap between Mise's simple tool management and Nix's powerful package ecosystem, giving you:

- **Reproducible environments**: Pin tools to exact versions with Nix's deterministic builds
- **Massive package selection**: Access to 100,000+ Nix packages
- **Cross-platform consistency**: Same tools and versions across Linux, macOS, and other platforms
- **Zero installation hassle**: No need to compile from source or manage dependencies manually
- **Private repository support**: Install tools from your company's private Git repositories and caches

Perfect for teams that want the reliability of Nix packages with the simplicity of Mise's tool management.

---

## Prerequisites

Before you get started, make sure you have installed:

* **[Mise](https://github.com/jdx/mise)** v2025.7.8+
* **[Nix](https://nixos.org/)**

---

## Installation

Install the plugin:

```sh
mise plugin install nix https://github.com/jbadeau/mise-nix.git
```

---

## Usage

### 1. Traditional NixHub Packages

Perfect for well-known tools with curated versions:

#### List available versions

```sh
mise ls-remote nix:helmfile
```

#### Install and use

```sh
# Install specific version
mise install nix:helmfile@1.1.2
mise exec nix:helmfile@1.1.2 -- helmfile version

# Install with version aliases
mise install nix:helmfile@stable   # Latest stable version
mise install nix:helmfile@latest   # Absolute latest (may include prereleases)
mise install nix:helmfile          # Latest by default

# Use in a project
mise use nix:helmfile@1.1.2
```

### 2. Flake References as Versions (Recommended)

This approach provides the best of both worlds - organized tool names with flexible flake sources:

```sh
# GitHub shorthand (recommended - clean and simple)
mise install nix:hello@nixos/nixpkgs#hello
mise exec nix:hello@nixos/nixpkgs#hello -- hello

# Tools from community overlays
mise install nix:emacs@nix-community/emacs-overlay#emacs-git
mise exec nix:emacs@nix-community/emacs-overlay#emacs-git -- emacs --version

# Use in projects
mise use nix:hello@nixos/nixpkgs#hello
mise use nix:ripgrep@nixpkgs#ripgrep
```

### 3. Direct Flake References as Tool Names

Use the flake reference directly as the tool identifier:

```sh
# GitHub shorthand
mise install nix:nixos/nixpkgs#hello
mise exec nix:nixos/nixpkgs#hello -- hello

# Full GitHub reference
mise install nix:github:nixos/nixpkgs#hello
mise exec nix:github:nixos/nixpkgs#hello -- hello

# nixpkgs shorthand
mise install nix:nixpkgs#fd
mise exec nix:nixpkgs#fd -- fd --version
```

### 4. Advanced Flake References

#### Git repositories

```sh
# Git HTTPS (public repositories)
mise install "nix:git+https://github.com/user/repo.git#package"

# Git HTTPS with authentication (private repositories)
mise install "nix:git+https://username:token@github.com/company/private-repo.git#tool"

# Git SSH (private repositories with SSH keys)
mise install "nix:git+ssh://git@company.com/tools/overlay.git#tool"

# With specific revision
mise install "nix:git+https://github.com/user/repo.git?rev=abc123#package"
```

#### Local flakes

```sh
# Relative path
mise install "nix:./my-flake#package"

# Absolute path
mise install "nix:/absolute/path/flake#tool"
```

**Security note:** Local flakes are disabled by default. Enable with:

```sh
export MISE_NIX_ALLOW_LOCAL_FLAKES=true
```

### Version Listing

```sh
# Traditional packages - full version history
mise ls-remote nix:helmfile

# Flake references - returns "latest"
mise ls-remote nix:nixpkgs#hello
```

### ❌ Known Limitation

Due to mise's core argument parsing, the following pattern is **not supported**:

```sh
# ❌ Does NOT work
mise install nix:hello@github:nixos/nixpkgs#hello
# Error: invalid prefix: github

# ✅ Use this instead
mise install nix:hello@nixos/nixpkgs#hello
```

The plugin automatically converts `nixos/nixpkgs` to `github:nixos/nixpkgs` internally.

---

## Advanced features

### Caching and performance

The plugin automatically caches package metadata from NixHub for improved performance:

- **Cache duration**: 1 hour by default
- **Cache location**: `~/.cache/mise-nix/`
- **Manual cache refresh**: Delete cache files or wait for expiration

```sh
# Clear cache for a specific tool
rm ~/.cache/mise-nix/helmfile.json

# Clear all cached metadata
rm -rf ~/.cache/mise-nix/
```

**Note:** Flake references bypass the plugin's metadata cache (since they don't use NixHub) but still benefit from Nix's binary caches for faster builds.

### Environment variables

You can customize the plugin behavior using environment variables:

```sh
# Use a different NixHub instance
export MISE_NIX_NIXHUB_BASE_URL="https://custom-nixhub.example.com"

# Use a different nixpkgs repository
export MISE_NIX_NIXPKGS_REPO_URL="https://github.com/MyOrg/nixpkgs"

# Enable local flake support (disabled by default for security)
export MISE_NIX_ALLOW_LOCAL_FLAKES=true
```

---

## Nix configuration

To use `mise-nix`, your Nix setup must support the following experimental features. Add these lines to your Nix
configuration file, typically located at `/etc/nix/nix.conf`:

```ini
experimental-features = nix-command flakes
substituters = https://cache.nixos.org
trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=
```

### Recommended: Additional substituters

For better package availability and faster builds, consider adding community binary caches:

```ini
substituters = https://cache.nixos.org https://nix-community.cachix.org
trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= nix-community.cachix.org-1:0VI8sF6Vsp2Jxw8+OFeVfYVdIY7X+GTtY+lR78QAbXs=
```

### Optional: Performance and security settings

```ini
# Allow flakes to specify their own configuration
accept-flake-config = true

# Set build parallelism (adjust based on your system)
max-jobs = 4

# For restricted environments (CI/containers) - avoid all local builds
max-jobs = 0
```

**Note:** With `max-jobs = 0`, Nix will fail if it cannot find the requested tool in your binary caches.

---

## Package source comparison

| Feature | NixHub packages | Flake references |
|---------|----------------|------------------|
| Source | Curated packages from nixhub.io | Direct from Nix flakes |
| Version listing | Full version history | Limited (latest/local) |
| Caching | Metadata cached for 1 hour | No metadata cache, uses Nix binary caches |
| Version aliases | `latest`, `stable` supported | Use flake URL revisions |
| Platform filtering | Automatic compatibility checking | Manual via flake outputs |
| Private repos | Not supported | ✅ Supported via git+ssh and git+https |
| Local development | Not applicable | ✅ Supported via local paths |
| PATH configuration | ✅ Works correctly | ✅ **Fixed** - now works correctly |
| Tool discovery | ✅ Works correctly | ✅ **Fixed** - now works correctly |

### When to use each approach

**Use NixHub packages when:**
- You want curated, tested packages
- You need to browse available versions easily
- You prefer faster installation with cached metadata
- You're using common development tools

**Use flake references when:**
- You need cutting-edge versions from upstream
- You're working with private repositories
- You're developing local flakes
- You need packages not available on NixHub
- You want to pin to specific commits/revisions

**Use "flake references as versions" when:**
- You want organized tool names with flexible sources
- You're managing multiple sources for the same tool type
- You prefer the `tool@source#package` pattern for clarity

---

## Environment variables from Nix

Nix packages often expose environment variables like `JAVA_HOME` via `nix-shell` or `nix develop`. However, these variables are **not automatically set** by `mise-nix`.

### Example: JDK

Using `nix-shell`:
```sh
echo $JAVA_HOME
# /nix/store/<hash>-openjdk-<version>/lib/openjdk
```

Using `mise-nix`:
```sh
mise exec -- java -version
# Works, but...
echo $JAVA_HOME
# Likely empty or unchanged
```

### Manual configuration
If your workflow depends on such variables, set them manually:

```sh
export JAVA_HOME="$(mise which java | sed 's|/bin/java||')"
```

## Working Examples

Here's a quick reference of patterns that work correctly:

```sh
# Traditional packages
mise install nix:jq@1.6
mise install nix:helmfile@stable
mise exec nix:jq@1.6 -- jq --version

# Flake references as versions (recommended)
mise install nix:hello@nixos/nixpkgs#hello
mise install nix:fd@nixpkgs#fd
mise exec nix:hello@nixos/nixpkgs#hello -- hello

# Direct flake references
mise install nix:nixos/nixpkgs#ripgrep
mise install nix:github:nixos/nixpkgs#git
mise install nix:nixpkgs#btop
mise exec nix:nixpkgs#ripgrep -- rg --version

# Git repositories
mise install "nix:git+https://github.com/nixos/nixpkgs.git#hello"

# Version listing
mise ls-remote nix:helmfile
mise ls-remote nix:nixpkgs#hello

# Project usage
mise use nix:node@nixpkgs#nodejs_20
mise use nix:python@nixpkgs#python311
```

## Troubleshooting

### Common issues

**"Nix is not installed or not in PATH"**
- Ensure Nix is properly installed and available in your shell
- Try running `nix --version` to verify installation

**"Tool not found or missing releases"**
- The package may not be available on NixHub
- Check [NixHub](https://www.nixhub.io) to verify the package exists
- Ensure you're using the correct package name
- For flakes, verify the flake reference and attribute path

**"invalid prefix: github"**
- This is a limitation in mise's argument parsing
- ❌ Don't use: `nix:hello@github:nixos/nixpkgs#hello`
- ✅ Use instead: `nix:hello@nixos/nixpkgs#hello`

**"multiple tools specified, use --all to uninstall all versions"**
- When uninstalling flake references that may have multiple installations
- Use: `mise uninstall nix:nixpkgs#hello --all`

**"No compatible versions found"**
- The package may not support your operating system or architecture
- Check the package's platform compatibility on NixHub
- For flakes, ensure the attribute exists in the flake outputs

**"Invalid flake reference format"**
- Ensure flake references include both URL and attribute: `url#attribute`
- Check that the flake URL is accessible and valid
- For private repos, ensure authentication is configured (SSH keys or HTTPS credentials)

**"Local flakes are disabled for security"**
- Local flakes are disabled by default as a security measure
- Set `MISE_NIX_ALLOW_LOCAL_FLAKES=true` to enable local flake support
- Ensure the local flake path is within the current working directory
- Avoid using paths that access sensitive system directories

**Build failures**
- Ensure you have the required Nix experimental features enabled
- Check that your Nix binary caches are accessible
- Consider setting `max-jobs = 0` if builds are failing in restricted environments
- For flakes, verify the flake is valid with `nix flake show <flake-url>`

### Performance tips

- Package metadata is cached for 1 hour to improve performance
- Large packages may take time to build - consider using binary caches
- Use `stable` version alias for more predictable builds
- Flake builds use Nix binary caches but may take longer on first run without prior cache hits

---

## Development

### init the plugin

```sh
mise init
```

### Run unit tests

Run Lua unit tests for helper functions:

```sh
mise test
```

### Run e2e tests

Run end-to-end integration tests using BATS:

```sh
mise e2e
```

The e2e tests (in `test/e2e.bats`) cover all major functionality including:
- Traditional NixHub package installation and execution
- Flake reference patterns (as versions and direct references)
- Security features for local flakes
- Directory structure validation
- Console output verification

Ensure all tests pass. If you make changes to functionality, be sure to update and rerun tests accordingly.

### Contributing

When contributing:

1. Ensure all utility functions are tested
2. Run the test suite before submitting changes
3. Follow the existing code style and patterns
4. Update documentation for new features