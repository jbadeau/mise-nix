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

### 1. NixHub Packages (Recommended)

NixHub is the preferred and most stable way to install packages. Perfect for well-known tools with curated versions:

#### List available versions

```sh
mise ls-remote nix:helmfile
```

#### Install and use

```sh
# Install specific version (verified working)
mise install nix:helmfile@1.1.2
mise exec nix:helmfile@1.1.2 -- helmfile version

# Install with version aliases (all tested and working)
mise install nix:helmfile@stable   # Latest stable version
mise install nix:helmfile@latest   # Absolute latest (may include prereleases)
mise install nix:helmfile          # Latest by default

# Use in a project
mise use nix:helmfile@1.1.2
```

### 2. Flake References (Experimental)

**⚠️ Experimental Feature**: Flake references are experimental and may have limitations or issues.

Use flake references with proper tool names for reliable shim creation:

```sh
# GitHub shorthand (tested and verified working)
mise install nix:hello@nixos/nixpkgs#hello
mise exec nix:hello@nixos/nixpkgs#hello -- hello
# Output: Hello, world!

# Tools from community overlays (pattern verified)
mise install nix:emacs@nix-community/emacs-overlay#emacs-git
mise exec nix:emacs@nix-community/emacs-overlay#emacs-git -- emacs --version

# Use in projects (verified working)
mise use nix:hello@nixos/nixpkgs#hello
mise use nix:ripgrep@nixpkgs#ripgrep
```

### 3. Private Git Repositories (Experimental)

**⚠️ Experimental Feature**: Private git repository access using custom prefixes that bypass mise's argument parsing limitations.

**Note**: Examples below use placeholder repository names. Replace `yourcompany`, `yourgroup`, etc. with your actual repository paths.

#### GitHub and GitLab Shorthand

```sh
# Private GitHub repositories (tested pattern - use gh- prefix)
mise install "nix:hello@gh-nixos/nixpkgs#hello"
mise exec "nix:hello@gh-nixos/nixpkgs#hello" -- hello
# Output: Hello, world!

# Private GitLab repositories (pattern example - replace with your repo)
mise install "nix:helm@gl-yourgroup/yourproject#helm"

# Legacy + syntax also supported (replace with your repos):
mise install "nix:kubectl@gh+yourcompany/k8s-tools#kubectl"
mise install "nix:helm@gl+yourgroup/charts#helm"
```

#### Full Git URLs

```sh
# SSH access to any git server (tested patterns - use ssh- prefix)
# Note: Full nixpkgs repo is very large, these examples are for smaller repos
mise install "nix:hello@ssh-git@github.com/nixos/nixpkgs.git#hello"  # Warning: Large repo!
mise install "nix:tool@ssh-git@gitlab.yourcompany.com/team/tools.git#tool"

# HTTPS with authentication (verified patterns - use https- prefix)  
# Note: For nixpkgs, prefer GitHub shorthand for faster builds
mise install "nix:hello@https-github.com/yourcompany/small-repo.git#hello"
mise install "nix:tool@https-user:token@gitlab.yourcompany.com/project.git#tool"

# Legacy + syntax also supported (replace with your repos):
mise install "nix:tool@ssh+git@github.com/yourcompany/private-repo.git#tool"
mise install "nix:tool@https+user:token@github.com/yourcompany/private-repo.git#tool"
```

#### Enterprise Instances

Configure environment variables for your enterprise instances:

```sh
# GitHub Enterprise (replace with your enterprise URL and repos)
export MISE_NIX_GITHUB_ENTERPRISE_URL="github.yourcompany.com"
mise install "nix:tool@ghe+yourteam/yourrepo#tool"

# GitLab instance (replace with your GitLab URL and repos)
export MISE_NIX_GITLAB_URL="gitlab.yourcompany.com"
mise install "nix:tool@gli+yourgroup/yourproject#tool"
```

### 4. Local Flakes (Experimental)

**⚠️ Experimental Feature**: Local flake references are experimental and require security configuration.

```sh
# Relative path
mise install "nix:package@./my-flake#package"

# Absolute path
mise install "nix:tool@/absolute/path/flake#tool"
```

**Security requirement:** Local flakes are disabled by default. Enable with:

```sh
export MISE_NIX_ALLOW_LOCAL_FLAKES=true
```

### Version Listing

```sh
# NixHub packages - full version history
mise ls-remote nix:helmfile

# Flake references - returns empty (no version listing)
mise ls-remote nix:hello@nixpkgs#hello
```

### ❌ Known Limitations

Due to mise's core argument parsing, some patterns are **not supported**:

```sh
# ❌ Does NOT work - mise rejects these prefixes
mise install nix:hello@github:nixos/nixpkgs#hello
# Error: invalid prefix: github

mise install "nix:hello@git+https://github.com/nixos/nixpkgs.git#hello"  
# Error: invalid prefix: git+https

# ✅ Use these working alternatives instead:
mise install nix:hello@nixos/nixpkgs#hello           # GitHub shorthand
mise install "nix:hello@gh-nixos/nixpkgs#hello"      # Custom GitHub prefix
mise install "nix:hello@https-github.com/nixos/nixpkgs.git#hello"  # Custom HTTPS prefix
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

## Custom Git Prefix Reference

The plugin supports custom prefixes that bypass mise's argument parsing limitations:

| Prefix Pattern | Converts To | Use Case |
|-----------------|-------------|----------|
| `gh+user/repo` | `github:user/repo` | Private GitHub repositories |
| `gl+group/project` | `gitlab:group/project` | Private GitLab repositories |
| `ssh+git@host/repo.git` | `git+ssh://git@host/repo.git` | SSH access to any git server |
| `https+user:token@host/repo.git` | `git+https://user:token@host/repo.git` | HTTPS with authentication |
| `ghe+user/repo` | `git+https://$GITHUB_ENTERPRISE/user/repo` | GitHub Enterprise (with env var) |
| `gli+group/project` | `git+https://$GITLAB_URL/group/project` | GitLab instance (with env var) |

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

Here's a quick reference of **tested and verified** patterns that work correctly:

```sh
# NixHub packages (all tested and working)
mise install nix:helmfile@1.1.2
mise install nix:helmfile@stable  
mise install nix:helmfile@latest
mise install nix:helmfile          # Latest by default
mise exec nix:helmfile@1.1.2 -- helmfile version

# Flake references (tested and verified)
mise install nix:hello@nixos/nixpkgs#hello
mise exec nix:hello@nixos/nixpkgs#hello -- hello
# Output: Hello, world!

# Custom git prefixes (all patterns tested)
mise install "nix:hello@gh-nixos/nixpkgs#hello"      # GitHub shorthand
mise exec "nix:hello@gh-nixos/nixpkgs#hello" -- hello
# Output: Hello, world!

mise install "nix:hello@ssh-git@github.com/nixos/nixpkgs.git#hello"  # SSH access
mise install "nix:hello@https-github.com/nixos/nixpkgs.git#hello"    # HTTPS access

# Version listing (tested behaviors)
mise ls-remote nix:helmfile                    # Returns version list
mise ls-remote nix:hello@nixpkgs#hello         # Returns empty (expected for flakes)

# Project usage (verified patterns)
mise use nix:hello@nixos/nixpkgs#hello
mise use nix:helmfile@1.1.2
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


**"multiple tools specified, use --all to uninstall all versions"**
- When uninstalling flake references that may have multiple installations
- Use: `mise uninstall nix:hello@nixpkgs#hello --all`

**"No compatible versions found"**
- The package may not support your operating system or architecture
- Check the package's platform compatibility on NixHub
- For flakes, ensure the attribute exists in the flake outputs

**"Invalid flake reference format"**
- Ensure flake references include both URL and attribute: `url#attribute`
- Check that the flake URL is accessible and valid

**"Local flakes are disabled for security"**
- Local flakes are disabled by default as a security measure
- Set `MISE_NIX_ALLOW_LOCAL_FLAKES=true` to enable local flake support
- When enabled, you'll see security warnings: `WARNING: Using local flake`
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

**⚠️ Warning about full git repositories:**
- Avoid using full git URLs for large repositories like `git+https://github.com/nixos/nixpkgs.git`
- These will clone the entire repository which can be very slow (nixpkgs is >1GB)
- Prefer GitHub shorthand (`nixos/nixpkgs`) which uses Nix's optimized fetching
- Use full git URLs only for smaller private repositories

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