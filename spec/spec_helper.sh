# shellcheck shell=sh

# Defining variables and functions here will affect all specfiles.
# Change shell options inside a function may cause different behavior,
# so it is better to set them here.
# set -eu

# This callback function will be invoked only once before loading specfiles.
spec_helper_precheck() {
  # Available functions: info, warn, error, abort, setenv, unsetenv
  # Available variables: VERSION, SHELL_TYPE, SHELL_VERSION
  : minimum_version "0.28.1"
  
  # Note: Environment variables for mise verbosity are set in .shellspec
}

# This callback function will be invoked after a specfile has been loaded.
spec_helper_loaded() {
  :
}

# Helper function to check directory structure
check_directory_structure() {
    local tool_spec="$1"
    local expected_name="$2"
    # Extract tool name after 'nix:' and before '@' if present
    local tool_name="$(echo "$tool_spec" | sed 's/^nix://' | cut -d@ -f1)"
    
    # Convert special characters in tool name for directory structure
    # # gets converted to -, / gets converted to -, etc.
    local dir_name="$(echo "$tool_name" | sed 's/#/-/g' | sed 's/\//-/g' | sed 's/:/-/g')"
    local install_dir="$HOME/.local/share/mise/installs/nix-$dir_name"
    
    # Check that the symlink exists and points to nix store
    test -L "$install_dir/$expected_name" || return 1
    
    local target=$(readlink "$install_dir/$expected_name")
    
    # For traditional nixhub installations, there might be intermediate symlinks
    # Resolve to final target
    local final_target="$target"
    if [[ "$target" =~ ^\. ]]; then
        # Relative symlink, resolve it
        final_target=$(readlink -f "$install_dir/$expected_name")
    fi
    
    echo "$final_target" | grep -q "^/nix/store/" || return 1
    
    # Also check that the final target contains a bin directory with executables
    test -d "$final_target/bin" || return 1
}

# Helper function to clean up nix tools (except essential ones for testing)
cleanup_nix_tools() {
    # Get list of all installed nix tools and uninstall them
    # Using mise ls --installed to get only installed tools, filtering for nix: prefix
    # Exclude shellspec which is needed for running tests
    mise ls --installed 2>/dev/null | grep '^nix:' | grep -v 'nix:shellspec' | while IFS= read -r line; do
        # Extract tool name from the output (format: "nix:tool@version   /path/to/install")
        tool=$(echo "$line" | awk '{print $1}')
        if [ -n "$tool" ]; then
            mise uninstall "$tool" 2>/dev/null || true
        fi
    done
    
    # Also clean up any leftover nix installation directories (except shellspec)
    if [ -d "$HOME/.local/share/mise/installs" ]; then
        find "$HOME/.local/share/mise/installs" -name "nix-*" -not -name "nix-shellspec" -type d -exec rm -rf {} + 2>/dev/null || true
    fi
    
    # Clean up cache directories (except shellspec)
    if [ -d "$HOME/Library/Caches/mise" ]; then
        find "$HOME/Library/Caches/mise" -name "nix-*" -not -name "nix-shellspec" -type d -exec rm -rf {} + 2>/dev/null || true
    fi
}

# Helper function to create test flake for local flake testing
create_test_flake() {
    test_flake_dir="/tmp/mise-test-flake"
    mkdir -p "$test_flake_dir"
    
    # Write flake.nix content using printf to avoid heredoc issues
    printf '%s\n' \
        '{' \
        '  description = "Test flake for mise-nix";' \
        '  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";' \
        '  outputs = { self, nixpkgs }: {' \
        '    packages.x86_64-linux.default = nixpkgs.legacyPackages.x86_64-linux.hello;' \
        '    packages.aarch64-darwin.default = nixpkgs.legacyPackages.aarch64-darwin.hello;' \
        '    packages.x86_64-darwin.default = nixpkgs.legacyPackages.x86_64-darwin.hello;' \
        '  };' \
        '}' > "$test_flake_dir/flake.nix"
}

# Helper function to clean up test flake
cleanup_test_flake() {
    rm -rf "/tmp/mise-test-flake" 2>/dev/null || true
}

# This callback function will be invoked after core modules has been loaded.
spec_helper_configure() {
  # Available functions: import, before_each, after_each, before_all, after_all
  : import 'support/custom_matcher'
  
  # Set up hooks to ensure clean test environment
  before_all 'cleanup_nix_tools'  # Clean up before all tests
  after_all 'cleanup_nix_tools'   # Clean up after all tests
  before_each 'cleanup_nix_tools' # Clean up before each test
  after_each 'cleanup_nix_tools'  # Clean up after each test
}
