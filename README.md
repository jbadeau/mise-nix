# `mise-nix`

`mise-nix` is a backend plugin for [Mise](https://github.com/jdx/mise) that allows you to install and manage
packages using [Nix](https://nixos.org/).

---

## Prerequisites

Before you get started, make sure you have installed:

* **[Mise](https://github.com/jdx/mise)**
* **[Nix](https://nixos.org/)**

---

### Nix configuration

To use `mise-nix`, your Nix setup must support the following experimental features. Add these lines to your Nix
configuration file, typically located at `/etc/nix/nix.conf`:

```ini
experimental-features = nix-command flakes
substitutes = true
```

### Optional: Restricted environments
If you want to avoid all local builds (e.g., in CI or restricted environments), add:

```ini
max-jobs = 0
```

**Note:** With `max-jobs = 0`, Nix will fail if it cannot find the requested tool in your binary caches.

---

## Installation

Install the plugin:

```sh
mise plugin install nix https://github.com/jbadeau/mise-nix.git
```

---

## Usage

### List available versions

```sh
mise ls-remote nix:helmfile
```

### Install a specific version

```sh
mise install nix:helmfile@1.1.2
```

### Use in a project

```sh
mise use nix:helmfile@1.1.2
```

### Run the tool

```sh
mise exec nix:helmfile@1.1.2 -- helmfile version
```

---

## Advanced features

### Version aliases

`mise-nix` supports several version aliases for convenience:

- `latest` - The most recent version available (including prereleases)
- `stable` - The most recent stable version (excluding alpha, beta, rc, etc.)

```sh
# Install latest stable version
mise install nix:go@stable

# Install absolute latest (may include prereleases)
mise install nix:go@latest
```

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

### Environment variables

You can customize the plugin behavior using environment variables:

```sh
# Use a different NixHub instance
export MISE_NIX_NIXHUB_BASE_URL="https://custom-nixhub.example.com"

# Use a different nixpkgs repository
export MISE_NIX_NIXPKGS_REPO_URL="https://github.com/MyOrg/nixpkgs"
```

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

**"No compatible versions found"**
- The package may not support your operating system or architecture
- Check the package's platform compatibility on NixHub

**Build failures**
- Ensure you have the required Nix experimental features enabled
- Check that your Nix binary caches are accessible
- Consider setting `max-jobs = 0` if builds are failing in restricted environments

### Performance tips

- Package metadata is cached for 1 hour to improve performance
- Large packages may take time to build - consider using binary caches
- Use `stable` version alias for more predictable builds

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