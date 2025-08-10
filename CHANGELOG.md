## 0.11.0 (2025-08-10)

### 🚀 Features

- make nixpkgs repository URL configurable via environment variable ([17fcb0f](https://github.com/jbadeau/mise-nix/commit/17fcb0f))
- Add vscode extension install support ([9019950](https://github.com/jbadeau/mise-nix/commit/9019950))
- Don't throw error on ls.remote if no compatible version(s) found ([92a04b9](https://github.com/jbadeau/mise-nix/commit/92a04b9))

### ❤️ Thank You

- jbadeau

## 0.10.0 (2025-08-03)

### 🚀 Features

- Improve flake installation examples and add performance warnings ([af9d6c0](https://github.com/jbadeau/mise-nix/commit/af9d6c0))

### ❤️ Thank You

- jbadeau

## 0.9.0-nx-release.0 (2025-08-02)

### 🚀 Features

- Fix flake reference PATH issues and migrate tests to BATS
- Fix PATH configuration for direct flake references (nix:nixos/nixpkgs#hello)
- Add workaround for mise's directory structure expectations with nix store hashes
- Enhance backend_exec_env.lua to resolve symlinks to actual nix store paths
- Migrate test suite from shell script to BATS format with proper assertions
- Add comprehensive console output verification and error handling
- Document GitHub prefix limitation in tool@version parsing
- Update README with working examples and troubleshooting guide
- Update mise e2e command to use new BATS test suite

### ❤️ Thank You

- jbadeau