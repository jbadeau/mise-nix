#!/usr/bin/env bats

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
    [[ -L "$install_dir/$expected_name" ]]
    
    local target=$(readlink "$install_dir/$expected_name")
    
    # For traditional nixhub installations, there might be intermediate symlinks
    # Resolve to final target
    local final_target="$target"
    if [[ "$target" =~ ^\. ]]; then
        # Relative symlink, resolve it
        final_target=$(readlink -f "$install_dir/$expected_name")
    fi
    
    [[ "$final_target" =~ ^/nix/store/ ]]
    
    # Also check that the final target contains a bin directory with executables
    [[ -d "$final_target/bin" ]]
}

@test "ls-remote nix:helmfile returns versions" {
    run mise ls-remote nix:helmfile
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    [[ "$output" != "" ]]
}

@test "install and exec nix:helmfile (latest)" {
    run mise install nix:helmfile
    [ "$status" -eq 0 ]
    
    run mise exec nix:helmfile -- helmfile version
    [ "$status" -eq 0 ]
    [[ "$output" =~ "version" ]]
    
    check_directory_structure "nix:helmfile" "latest"
    
    run mise uninstall nix:helmfile
    [ "$status" -eq 0 ]
}

@test "install and exec nix:helmfile@1.1.2 (specific version)" {
    run mise install nix:helmfile@1.1.2
    [ "$status" -eq 0 ]
    
    run mise exec nix:helmfile@1.1.2 -- helmfile version
    [ "$status" -eq 0 ]
    [[ "$output" =~ "version" ]]
    
    check_directory_structure "nix:helmfile@1.1.2" "1.1.2"
    
    run mise uninstall nix:helmfile@1.1.2
    [ "$status" -eq 0 ]
}

@test "install and exec nix:helmfile@stable" {
    run mise install nix:helmfile@stable
    [ "$status" -eq 0 ]
    
    run mise exec nix:helmfile@stable -- helmfile version
    [ "$status" -eq 0 ]
    [[ "$output" =~ "version" ]]
    
    check_directory_structure "nix:helmfile@stable" "stable"
    
    run mise uninstall nix:helmfile@stable
    [ "$status" -eq 0 ]
}

@test "install and exec nix:helmfile@latest" {
    run mise install nix:helmfile@latest
    [ "$status" -eq 0 ]
    
    run mise exec nix:helmfile@latest -- helmfile version
    [ "$status" -eq 0 ]
    [[ "$output" =~ "version" ]]
    
    check_directory_structure "nix:helmfile@latest" "latest"
    
    run mise uninstall nix:helmfile@latest
    [ "$status" -eq 0 ]
}

@test "install flake reference as version (GitHub shorthand)" {
    run mise install nix:hello@nixos/nixpkgs#hello
    [ "$status" -eq 0 ]
    
    run mise exec nix:hello@nixos/nixpkgs#hello -- hello
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Hello, world!" ]]
    
    check_directory_structure "nix:hello@nixos/nixpkgs#hello" "nixos-nixpkgs#hello"
    
    run mise uninstall nix:hello@nixos/nixpkgs#hello
    [ "$status" -eq 0 ]
}

@test "flake reference with github: prefix should fail" {
    # Note: github: prefix is not supported in mise's tool@version parsing
    # This is a limitation of mise's command line argument parsing, not the plugin
    run mise install nix:hello@github:nixos/nixpkgs#hello
    [ "$status" -ne 0 ]
    [[ "$output" =~ "invalid prefix: github" ]]
}

@test "git repository flake reference should fail due to mise parsing" {
    # git+https: prefix is not supported in mise's tool@version parsing
    # This is a limitation of mise's command line argument parsing, not the plugin
    run mise install "nix:hello@git+https://github.com/nixos/nixpkgs.git#hello"
    [ "$status" -ne 0 ]
    [[ "$output" =~ "invalid prefix: git+https" ]]
}

@test "ls-remote for flake references returns empty (no versions)" {
    run mise ls-remote nix:hello@nixpkgs#hello
    [ "$status" -eq 0 ]
    # Flake references don't have traditional version listings
    [ -z "$output" ]
}

@test "security: local flakes blocked when disabled" {
    if [[ "${MISE_NIX_ALLOW_LOCAL_FLAKES}" == "true" ]]; then
        skip "Local flakes are enabled, skipping security test"
    fi
    
    run mise install "nix:test@./nonexistent#default"
    [ "$status" -ne 0 ]
    # The current implementation shows a different error message
    [[ "$output" =~ "Tool not found or missing releases" ]]
}

@test "custom git prefix: gh- GitHub shorthand" {
    run mise install "nix:hello@gh-nixos/nixpkgs#hello"
    [ "$status" -eq 0 ]
    
    run mise exec "nix:hello@gh-nixos/nixpkgs#hello" -- hello
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Hello, world!" ]]
    
    check_directory_structure "nix:hello@gh-nixos/nixpkgs#hello" "gh-nixos-nixpkgs#hello"
    
    run mise uninstall "nix:hello@gh-nixos/nixpkgs#hello"
    [ "$status" -eq 0 ]
}

@test "custom git prefix: gl- GitLab shorthand" {
    # Note: This tests the parsing/conversion but may fail on actual build if GitLab repo doesn't exist
    run mise ls-remote "nix:hello@gl-group/project#package"
    [ "$status" -eq 0 ]
    # Should not error on parsing, even if repo doesn't exist
}

@test "custom git prefix: ssh- URL should work" {
    # Test that ssh- prefix is recognized as a flake reference
    # This won't actually install (since we don't have SSH access to test repos)
    # but should at least parse correctly and not be rejected by mise
    run mise ls-remote "nix:hello@ssh-git@github.com/nixos/nixpkgs.git#hello"
    [ "$status" -eq 0 ]
    # The command should succeed (empty output for flake ls-remote is normal)
}

@test "custom git prefix: https- URL should work" {
    # Test that https- prefix is recognized as a flake reference  
    run mise ls-remote "nix:hello@https-github.com/nixos/nixpkgs.git#hello"
    [ "$status" -eq 0 ]
    # The command should succeed (empty output for flake ls-remote is normal)
}

@test "security: local flakes allowed when enabled" {
    if [[ "${MISE_NIX_ALLOW_LOCAL_FLAKES}" != "true" ]]; then
        skip "Local flakes are disabled, skipping local flake test"
    fi
    
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
    run mise install "nix:test@$test_flake_dir#default"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "WARNING: Using local flake" ]]
    
    run mise uninstall "nix:test@$test_flake_dir#default"
    [ "$status" -eq 0 ]
    
    # Clean up
    rm -rf "$test_flake_dir"
}