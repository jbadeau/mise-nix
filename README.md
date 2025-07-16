# mise-nix

A [mise](https://github.com/jdx/mise) backend plugin for installing tools using [Nix](https://nixos.org/).

You can manually search for packages at [NixHub](https://www.nixhub.io/)

## Prerequisites
- Nix

## Installation

Install the plugin
```shell
mise plugin install nix https://github.com/jbadeau/mise-nix.git
```

List available versions
```shell
mise ls-remote nix:helmfile
```

Install a specific version
```shell
mise install nix:helmfile@1.1.2
```

Use in a project
```shell
mise use nix:helmfile@1.1.2
```

Execute the tool
```shell
mise exec -- helmfile --version
```

## Local Development
Install the plugin
```shell
mise plugin link nix /path/to/mise-nix
```
