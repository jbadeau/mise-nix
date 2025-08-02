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

### Traditional package installation (via NixHub)

#### List available versions

```sh
mise ls-remote nix:helmfile
```

#### Install a specific version

```sh
mise install nix:helmfile@1.1.2
```

#### Use in a project

```sh
mise use nix:helmfile@1.1.2
```

#### Run the tool

```sh
mise exec nix:helmfile@1.1.2 -- helmfile version
```

#### Version aliases

`mise-nix` supports several version aliases for convenience with NixHub packages:

- `latest` - The most recent version available (including prereleases)
- `stable` - The most recent stable version (excluding alpha, beta, rc, etc.)

```sh
# Install latest stable version
mise install nix:go@stable

# Install absolute latest (may include prereleases)
mise install nix:go@latest
```

**Note:** Version aliases work with traditional NixHub packages. For flake references, use specific revisions or branches in the flake URL itself.

### Flake reference installation

`mise-nix` also supports installing packages directly from Nix flakes using various reference formats:

#### GitHub repositories

```sh
# GitHub shorthand
mise install "nix:nix-community/emacs-overlay#emacs-git"

# Full GitHub reference
mise install "nix:github:nixos/nixpkgs#hello"

# With specific revision/branch
mise install "nix:github:nixos/nixpkgs/abc123#hello"
```

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

**Security note:** Local flakes are disabled by default for security reasons. To enable local flake support, set the environment variable:

```sh
export MISE_NIX_ALLOW_LOCAL_FLAKES=true
```

When enabled, local flakes are restricted to safe paths within the current working directory to prevent access to sensitive system directories.

#### Flake reference as version

You can also specify a flake reference as the version, which allows for more flexible package management:

```sh
# Install with flake reference as version
mise install "nix:hello@nixos/nixpkgs#hello"
mise install "nix:emacs@nix-community/emacs-overlay#emacs-git"

# Use in a project with flake reference version
mise use "nix:hello@github:nixos/nixpkgs#hello"

# Run with flake reference version
mise exec "nix:emacs@nix-community/emacs-overlay#emacs-git" -- emacs --version
```

This approach provides better organization by separating the tool name from the flake source, making it easier to manage multiple sources for the same tool.

#### Usage with flakes

```sh
# Use in a project
mise use "nix:github:nixos/nixpkgs#hello"

# Run the tool
mise exec "nix:nix-community/emacs-overlay#emacs-git" -- emacs --version

# List available versions (limited for flakes)
mise ls-remote "nix:github:nixos/nixpkgs#hello"
```

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
| Private repos | Not supported | Supported via git+ssh and git+https |
| Local development | Not applicable | Supported via local paths |

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

unit
```sh
mise test
```

### Run e2e tests

```sh
mise e2e
```

Ensure all tests pass. If you make changes to utility functions or logic, be sure to update and rerun tests accordingly.

### Contributing

When contributing:

1. Ensure all utility functions are tested
2. Run the test suite before submitting changes
3. Follow the existing code style and patterns
4. Update documentation for new features