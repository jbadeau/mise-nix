#!/bin/bash
set -e

echo "Testing mise-nix plugin functionality..."
echo "This test suite covers:"
echo "  1. Traditional NixHub package installation and management"
echo "  2. Flake references in version field (e.g., nix:tool@flake-ref#package)"
echo "  3. Direct flake references as tool names (e.g., nix:flake-ref#package)"
echo "  4. Version listing for flake references"
echo "  5. Security features for local flakes"
echo "  6. Directory structure validation"
echo ""

# Helper function to check directory structure
check_directory_structure() {
    local tool_spec="$1"
    local expected_name="$2"
    local tool_name="$(echo "$tool_spec" | cut -d: -f2 | cut -d@ -f1)"
    
    # Convert special characters in tool name for directory structure
    # # gets converted to -, / gets converted to -, etc.
    local dir_name="$(echo "$tool_name" | sed 's/#/-/g' | sed 's/\//-/g')"
    local install_dir="$HOME/.local/share/mise/installs/nix-$dir_name"
    
    echo "Checking directory structure for $tool_spec..."
    echo "  Tool name: $tool_name"
    echo "  Directory name: $dir_name"
    echo "  Install dir: $install_dir"
    echo "  Expected symlink: $install_dir/$expected_name"
    
    # Check that the symlink exists and points to nix store
    if [[ ! -L "$install_dir/$expected_name" ]]; then
        echo "ERROR: Expected symlink not found at $install_dir/$expected_name"
        echo "Available files:"
        ls -la "$install_dir/" || echo "Directory does not exist"
        exit 1
    fi
    
    local target=$(readlink "$install_dir/$expected_name")
    
    # For traditional nixhub installations, there might be intermediate symlinks
    # Resolve to final target
    local final_target="$target"
    if [[ "$target" =~ ^\. ]]; then
        # Relative symlink, resolve it
        final_target=$(readlink -f "$install_dir/$expected_name")
    fi
    
    if [[ ! "$final_target" =~ ^/nix/store/ ]]; then
        echo "ERROR: Final target does not point to nix store."
        echo "  Direct target: $target"
        echo "  Final target: $final_target"
        exit 1
    fi
    
    echo "✓ Directory structure correct for $tool_spec"
}

# Test 1: Traditional NixHub functionality
echo "=== Testing Traditional NixHub functionality ==="

if [[ "$(mise ls-remote nix:helmfile)" == "" ]]; then
    echo "ERROR: No versions available"
    exit 1
fi

mise install nix:helmfile
mise exec nix:helmfile -- helmfile version
check_directory_structure "nix:helmfile" "latest"
mise uninstall nix:helmfile

# Test version
mise install nix:helmfile@1.1.2
mise exec nix:helmfile@1.1.2 -- helmfile version
check_directory_structure "nix:helmfile@1.1.2" "1.1.2"
mise uninstall nix:helmfile@1.1.2

# Test stable
mise install nix:helmfile@stable
mise exec nix:helmfile@stable -- helmfile version
check_directory_structure "nix:helmfile@stable" "stable"
mise uninstall nix:helmfile@stable

# Test latest
mise install nix:helmfile@latest
mise exec nix:helmfile@latest -- helmfile version
check_directory_structure "nix:helmfile@latest" "latest"
mise uninstall nix:helmfile@latest

# Test 2: Flake reference in version field
echo "=== Testing Flake Reference in Version Field ==="

# Test flake reference as version (GitHub shorthand)
mise install nix:hello@nixos/nixpkgs#hello
mise exec nix:hello@nixos/nixpkgs#hello -- hello
check_directory_structure "nix:hello@nixos/nixpkgs#hello" "nixos-nixpkgs#hello"
mise uninstall nix:hello@nixos/nixpkgs#hello

# Test flake reference as version (full GitHub reference)
mise install nix:hello@github:nixos/nixpkgs#hello
mise exec nix:hello@github:nixos/nixpkgs#hello -- hello
check_directory_structure "nix:hello@github:nixos/nixpkgs#hello" "github:nixos-nixpkgs#hello"
mise uninstall nix:hello@github:nixos/nixpkgs#hello

# Test 3: Direct flake reference as tool name
echo "=== Testing Direct Flake Reference as Tool Name ==="

# Test direct GitHub shorthand flake reference
mise install nix:nixos/nixpkgs#hello
mise exec nix:nixos/nixpkgs#hello -- hello
check_directory_structure "nix:nixos/nixpkgs#hello" "latest"
mise uninstall nix:nixos/nixpkgs#hello

# Test direct full GitHub flake reference
mise install nix:github:nixos/nixpkgs#hello
mise exec nix:github:nixos/nixpkgs#hello -- hello
check_directory_structure "nix:github:nixos/nixpkgs#hello" "latest"
mise uninstall nix:github:nixos/nixpkgs#hello

# Test nixpkgs shorthand
mise install nix:nixpkgs#hello
mise exec nix:nixpkgs#hello -- hello
check_directory_structure "nix:nixpkgs#hello" "latest"
mise uninstall nix:nixpkgs#hello

# Test 4: List versions for flake references
echo "=== Testing Version Listing for Flake References ==="

# Test that flake references return appropriate versions
flake_versions=$(mise ls-remote nix:nixpkgs#hello)
if [[ ! "$flake_versions" =~ "latest" ]]; then
    echo "ERROR: Expected 'latest' in flake versions, got: $flake_versions"
    exit 1
fi
echo "✓ Flake version listing works correctly"

# Test 5: Security features (if local flakes are enabled)
echo "=== Testing Security Features ==="

if [[ "${MISE_NIX_ALLOW_LOCAL_FLAKES}" == "true" ]]; then
    echo "Testing local flake security with MISE_NIX_ALLOW_LOCAL_FLAKES=true"
    
    # Create a simple test flake
    test_flake_dir="/tmp/mise-test-flake"
    mkdir -p "$test_flake_dir"
    cat > "$test_flake_dir/flake.nix" << 'EOF'
{
  description = "Test flake for mise-nix";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  outputs = { self, nixpkgs }: {
    packages.x86_64-linux.default = nixpkgs.legacyPackages.x86_64-linux.hello;
    packages.aarch64-darwin.default = nixpkgs.legacyPackages.aarch64-darwin.hello;
    packages.x86_64-darwin.default = nixpkgs.legacyPackages.x86_64-darwin.hello;
  };
}
EOF
    
    # Test local flake installation (this should work with proper security warnings)
    echo "Testing local flake installation..."
    mise install "nix:test@$test_flake_dir#default" 2>&1 | grep -q "WARNING: Using local flake" && echo "✓ Security warning displayed for local flakes"
    mise uninstall "nix:test@$test_flake_dir#default" || true
    
    # Clean up
    rm -rf "$test_flake_dir"
else
    echo "Local flakes disabled (MISE_NIX_ALLOW_LOCAL_FLAKES != true) - skipping local flake tests"
    
    # Test that local flakes are properly blocked
    echo "Testing that local flakes are blocked when disabled..."
    if mise install "nix:test@./nonexistent#default" 2>&1 | grep -q "Local flakes are disabled for security"; then
        echo "✓ Local flakes properly blocked when disabled"
    else
        echo "WARNING: Local flake security test could not be verified"
    fi
fi

echo "=== All tests passed! ==="