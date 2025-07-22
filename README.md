# `mise-nix`

`mise-nix` is a backend plugin for [Mise](https://github.com/jdx/mise) that allows you to install and manage
packages using [Nix](https://nixos.org/).

---

## Why

- **Nix is powerful, but complex**: Setting up Nix to work reliably in typical development workflows often requires deep domain knowledge and custom configuration.
- **Direnv is flexible, but slow**: Tools like `direnv` enable project-based environments but can introduce noticeable delays in shell startup time.

`mise-nix` brings the best of both worlds:
- Access thousands of reproducible Nix packages from [NixHub](https://www.nixhub.io/)
- Use familiar `mise` commands to install and manage tools without writing `shell.nix` or `flake.nix`
- Integrate environment variables, package versions, and tasks into a single, performant, and declarative configuration.
- Avoid the learning curve of traditional Nix usage while still benefiting from its features 

---

## Prerequisites

Before you get started, make sure you have installed:

* **[Mise](https://github.com/jdx/mise)**
* **[Nix](https://nixos.org/)**

---

### Nix Configuration

To use `mise-nix`, your Nix setup must support the following experimental features. Add these lines to your Nix 
configuration file, typically located at `/etc/nix/nix.conf`:

```ini
experimental-features = nix-command flakes
substitute = true
```

### Optional: Restricted Environments
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

### List Available Versions

```sh
mise ls-remote nix:helmfile
```

### Install a Specific Version

```sh
mise install nix:helmfile@1.1.2
```

Install the latest version:

```sh
mise install nix:helmfile
```

### Use in a Project

```sh
mise use nix:helmfile@1.1.2
```

### Run the Tool

```sh
mise exec -- helmfile --version
```

---

## Environment Variables from Nix

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

### Manual Configuration
If your workflow depends on such variables, set them manually:

```sh
export JAVA_HOME="$(mise which java | sed 's|/bin/java||')"
```

*Future improvement: Automatic parsing of Nix derivation environment variables is on the roadmap.*

---

## Development

### Initialize the Plugin

```sh
mise init
```

### Running Tests

Run the test suite to verify plugin functionality:

```sh
lua test_utils.lua
```

Ensure all tests pass. If you make changes to utility functions or logic, be sure to update and rerun tests accordingly.
