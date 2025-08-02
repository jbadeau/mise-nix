## 0.9.0-nx-release.0 (2025-08-02)

### 🚀 Features

- Fix flake reference PATH issues and migrate tests to BATS   - Fix PATH configuration for direct flake references (nix:nixos/nixpkgs#hello)   - Add workaround for mise's directory structure expectations with nix store hashes   - Enhance backend_exec_env.lua to resolve symlinks to actual nix store paths   - Migrate test suite from shell script to BATS format with proper assertions   - Add comprehensive console output verification and error handling   - Document GitHub prefix limitation in tool@version parsing   - Update README with working examples and troubleshooting guide   - Update mise e2e command to use new BATS test suite ([4e3462c](https://github.com/jbadeau/mise-nix/commit/4e3462c))

### ❤️ Thank You

- jbadeau