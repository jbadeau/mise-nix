# mise-nix

A [mise](https://github.com/jdx/mise) backend plugin that installs tools using the [Nix package manager](https://nixos.org/).

This plugin automatically resolves and installs platform-compatible versions using metadata from [NixHub](https://www.nixhub.io/).

---

## Features

- Seamless integration with `mise`
- Platform-aware: installs only compatible versions for your OS and architecture
- Works with tools available via [NixHub](https://www.nixhub.io/)
- Uses the Nix binary cache (builds only if necessary)

---

## Prerequisites

- [Mise](https://github.com/jdx/mise)
- [Nix](https://nixos.org/download.html)

---

## Installation

Install the plugin:

```bash
mise plugin install nix https://github.com/jbadeau/mise-nix.git
```

---

## Usage

### List available versions for your platform

```bash
mise ls-remote nix:helmfile
```

### Install a specific version

```bash
mise install nix:helmfile@1.1.2
```

### Use in a project

```bash
mise use nix:helmfile@1.1.2
```

### Execute the tool

```bash
mise exec -- helmfile --version
```

---

## Configuration

By default, the plugin will build packages if they are not available in the Nix cache.

To use only cached binaries and prevent builds, set:

```bash
export MISE_NIX_ONLY_CACHED=1
```

---

## Development

Link your local clone of the plugin into `mise`:

```bash
mise init
```

You can then test locally with:

```bash
mise use nix:<tool>
```

---

## Testing

Run Lua unit tests:

```bash
lua test_utils.lua
```

---

## Resources

- [NixHub](https://www.nixhub.io/)
- [NixOS Manual](https://nixos.org/manual/)
- [Mise Documentation](https://mise.jdx.dev)

---

@jbadeau