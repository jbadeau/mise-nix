# mise-nix

A [mise](https://github.com/jdx/mise) plugin backend for installing tools via [Nix](https://nixos.org/).

You can browse packages manually on [NixHub](https://www.nixhub.io/).

## Prerequisites

- [Mise](https://github.com/jdx/mise)
- [Nix](https://nixos.org/)

### Nix Configuration

To ensure the plugin works correctly, add the following to your Nix configuration:

```ini
experimental-features = nix-command flakes
substitute = true
```

Location: `nix.conf` (commonly found at `/etc/nix/nix.conf`, depending on your system)

If you're in an airgapped or restricted environment and want to strictly avoid local builds, you may optionally add:

```ini
max-jobs = 0
```

This disables all local builds, so installations will only succeed if the requested tools are available in your configured binary caches. If a binary is not available, the install will fail.

Make sure your system is configured to use trusted binary caches like `https://cache.nixos.org` or any [Cachix](https://www.cachix.org/) cache you rely on.

## Installation

```sh
mise plugin install nix https://github.com/jbadeau/mise-nix.git
```

## Usage

List available versions:

```sh
mise ls-remote nix:helmfile
```

Install a specific version:

```sh
mise install nix:helmfile@1.1.2
```

Use in a project:

```sh
mise use nix:helmfile@1.1.2
```

Run the tool:

```sh
mise exec -- helmfile --version
```

## Development

Initialize the plugin for development:

```sh
mise init
```

### Running Tests

You can run the test suite to validate the plugin utilities:

```sh
lua test_utils.lua
```

All tests should pass successfully. If you add or modify utility functions, be sure to update and rerun the test suite.
