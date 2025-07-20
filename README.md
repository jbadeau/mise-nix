# mise-nix

`mise-nix` is a backend plugin for [mise](https://github.com/jdx/mise) that allows you to easily install and manage 
development package using [Nix](https://nixos.org/).

---

## Why Use?

Leverage Nix's vast package collection and reproducible builds directly within your `mise` workflows. This plugin makes 
it easy to:

* **Access thousands of packages:** Browse available packages on [NixHub](https://www.nixhub.io/).
* **Ensure reproducible environments:** Benefit from Nix's robust dependency management.
* **Simplify package installation:** Use familiar `mise` commands for Nix-based installations. 
* **Great DX:** While there are many Nix frontends available, I personally enjoy the developer 
  experience that `mise` provides. It gives me a single, consistent frontend to manage not only my tools and packages, 
  but also environment variables and tasks.
---

## Prerequisites

Before you get started, make sure you have:

* **[Mise](https://github.com/jdx/mise)**: Your primary tool manager.
* **[Nix](https://nixos.org/)**: The package manager powering this plugin.

---

## Nix Configuration

For `mise-nix` to function correctly, you'll need to enable specific experimental features in your Nix configuration 
file, typically located at `/etc/nix/nix.conf`.

Add the following lines:

```ini
experimental-features = nix-command flakes
substitute = true
```

### Airgapped or Restricted Environments
If you operate in a restricted environment and need to strictly prevent local builds, you can 
optionally add:

```ini
max-jobs = 0
```

**Important:** Setting `max-jobs = 0` will disable all local builds.
Installations will only succeed if the requested tools are available in your configured binary caches 
(e.g., https://cache.nixos.org or any Cachix cache you rely on). If a binary isn't found in your caches, the 
installation will fail.

---

## Installation

Install the `mise-nix` plugin with a single command:

```sh
mise plugin install nix https://github.com/jbadeau/mise-nix.git
```

---

## Usage

### List Available Versions
List which versions of a package are available for your platform:

```sh
mise ls-remote nix:helmfile
```

### Install a Specific Version
Install a desired version of a package:

```sh
mise install nix:helmfile@1.1.2
```

Install the latest available version:

```sh
mise install nix:helmfile
```

### Use in a Project
Specify the tool version for your project, often done within a `mise.toml` file:

```sh
mise use nix:helmfile@1.1.2
```

Use the latest available version:

```sh
mise use nix:helmfile@1.1.2
```

### Run the Tool
Execute a Nix-installed tool:

```sh
mise exec -- helmfile --version
```

---

## Environment Variables from Nix

Nix often exposes important environment variables (e.g., `JAVA_HOME` for JDKs) when tools are used via `nix-shell` or 
`nix develop`. However, these environment variables are **not automatically set** when you use the `mise-nix` plugin.

### Example Scenario

If you install JDK using Nix, `nix-shell` might show:

```sh
echo $JAVA_HOME
# /nix/store/<hash>-openjdk-<version>/lib/openjdk
```

But when using `mise-nix`:

```sh
mise exec -- java -version
# Executes Java successfully

echo $JAVA_HOME
# Will likely be empty or unchanged
```

### Manual Configuration Required

If your environment depends on these specific variables, you'll need to configure them manually. For 
instance, to set `JAVA_HOME`:

```sh
export JAVA_HOME="$(mise which java | sed 's|/bin/java||')"
```

**Future Improvement:** We aim to add automatic parsing of environment variables from Nix derivations in a future 
update, but for now, manual configuration is necessary.

---

## Development

### Initialize the Plugin

```sh
mise init
```

### Running Tests

To ensure everything is working as expected, run the test suite:

```sh
lua test_utils.lua
```

All tests should pass. If you modify utility functions, remember to update and rerun the test suite accordingly.
