# `mise-nix`

`mise-nix` is a backend plugin for [mise](https://github.com/jdx/mise) that allows you to install and manage development
packages using [Nix](https://nixos.org/).

---

## Why

Nix is a powerful package manager that provides reproducible and declarative builds. However, it can be complex to 
integrate into daily workflows. `mise-nix` bridges this gap by offering:

* **Access to thousands of packages:** Easily browse available tools on [NixHub](https://www.nixhub.io/).
* **Reproducible environments:** Ensure consistency across machines with Nix’s robust dependency management.
* **Simple, intuitive CLI:** Leverage the familiar `mise` commands to install and manage tools using Nix.
* **Unified developer workflow:** Rather than juggling multiple tools, `mise` provides a single frontend for managing tools, versions, environment variables, and tasks.
* **Great DX (Developer Experience):** While there are many frontends for Nix, `mise` offers a performant and consistent interface that’s easy to adopt and pleasant to use.

---

## Prerequisites

Before you get started, make sure you have:

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

### Optional: Airgapped or Restricted Environments
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
