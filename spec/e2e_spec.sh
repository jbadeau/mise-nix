Describe "mise-nix plugin"
  Describe "Quick Start examples"
    It "can list available versions for nix:hello"
      When call mise ls-remote nix:hello
      The status should be success
      The output should include "2.12.1"
      The output should include "2.12"
      The output should include "2.10"
    End

    It "can install nix:hello@2.12.1 (specific version)"
      When call mise install nix:hello@2.12.1
      The status should be success
      The output should include "Successfully installed hello@2.12.1"
    End

    It "can execute nix:hello@2.12.1"
      When call mise exec nix:hello@2.12.1 -- hello
      The status should be success
      The output should include "Hello, world!"
    End
  End

  Describe "Standard Nixpkgs Packages (nixhub.io)"
    It "can install nix:hello (latest version)"
      When call mise install nix:hello
      The status should be success
      The output should include "Successfully installed hello@"
    End

    It "can install nix:hello@stable (version alias)"
      When call mise install nix:hello@stable
      The status should be success
      The output should include "Successfully installed hello@"
    End
  End

  Describe "GitHub Sources"
    It "can install from nixpkgs GitHub repository (default branch)"
      When call mise install "nix:hello@github+nixos/nixpkgs#hello"
      The status should be success
      The output should include "Building flake"
    End

    It "can execute hello from GitHub source"
      When call mise exec "nix:hello@github+nixos/nixpkgs#hello" -- hello
      The status should be success
      The output should include "Hello, world!"
    End

    It "can install from specific branch"
      When call mise install "nix:hello@github+nixos/nixpkgs/nixos-unstable#hello"
      The status should be success
      The output should include "Building flake"
    End

    It "can install from specific release/tag"
      When call mise install "nix:hello@github+nixos/nixpkgs?ref=23.11#hello"
      The status should be success
      The output should include "Building flake"
    End

    It "supports GitHub shorthand syntax (alternative)"
      When call mise ls-remote "nix:hello@nixos/nixpkgs#hello"
      The status should be success
      The output should be blank
    End
  End

  Describe "GitLab Sources"
    It "can parse gitlab+ prefix for ls-remote"
      # Tests that gitlab+ prefix is correctly recognized as a flake reference
      # Uses a fake project - ls-remote just validates parsing, doesn't fetch
      When call mise ls-remote "nix:mytool@gitlab+group/subgroup/project#default"
      The status should be success
    End

    It "can parse nested GitLab groups"
      # Tests deeply nested group paths like gitlab+a/b/c/d#pkg
      When call mise ls-remote "nix:mytool@gitlab+org/team/subteam/repo#default"
      The status should be success
    End
  End

  Describe "VSCode Extensions (Experimental)"
    It "can list VSCode extension versions"
      When call mise ls-remote "nix:vscode+install=vscode-extensions.golang.go"
      The status should be success
      The output should include "latest"
    End

    It "can install VSCode extensions"
      When call mise install "nix:vscode+install=vscode-extensions.golang.go"
      The status should be success
      The output should include "Successfully installed"
    End
  End

  Describe "Known Limitations - Git Hosting Shorthand"
    It "fails with direct github: prefix"
      When call mise install nix:hello@github:nixos/nixpkgs#hello
      The status should be failure
      The error should include "invalid prefix: github"
    End

    It "fails with direct gitlab: prefix"
      When call mise install nix:mytool@gitlab:group/project#default
      The status should be failure
      The error should include "invalid prefix: gitlab"
    End
  End

  Describe "Known Limitations - Git URL Workarounds"
    It "fails with git+ssh:// prefix"
      When call mise install "nix:hello@git+ssh://git@github.com/nixos/nixpkgs.git"
      The status should be failure
      The error should include "invalid prefix: git+ssh"
    End

    It "fails with git+https:// prefix"
      When call mise install "nix:hello@git+https://github.com/nixos/nixpkgs.git#hello"
      The status should be failure
      The error should include "invalid prefix: git+https"
    End

    It "supports ssh+ workaround syntax"
      When call mise ls-remote "nix:hello@ssh+git@github.com/nixos/nixpkgs.git"
      The status should be success
    End

    It "supports https+ workaround syntax for ls-remote"
      # Uses nurl - a small nix-community flake (~1MB vs nixpkgs ~300MB)
      When call mise ls-remote "nix:nurl@https+github.com/nix-community/nurl.git#default"
      The status should be success
    End

    It "can install using https+ workaround syntax"
      # Uses nurl - a small nix-community flake for faster tests
      When call mise install "nix:nurl@https+github.com/nix-community/nurl.git#default"
      The status should be success
      The output should include "Building flake"
    End
  End

  Describe "Unfree Packages"
    It "fails to install unfree package without NIXPKGS_ALLOW_UNFREE"
      Skip if "NIXPKGS_ALLOW_UNFREE is set" [ -n "${NIXPKGS_ALLOW_UNFREE}" ]
      Skip if "MISE_NIX_ALLOW_UNFREE is set" [ "${MISE_NIX_ALLOW_UNFREE}" = "true" ]

      When call mise install nix:discord
      The status should be failure
      The error should include "unfree"
    End

    It "can install unfree package with NIXPKGS_ALLOW_UNFREE=1"
      export NIXPKGS_ALLOW_UNFREE=1
      When call mise install nix:discord
      The status should be success
      The output should include "Successfully installed discord"
    End

    It "can install unfree package with MISE_NIX_ALLOW_UNFREE=true (auto-sets NIXPKGS)"
      export MISE_NIX_ALLOW_UNFREE=true
      # NIXPKGS_ALLOW_UNFREE is auto-set by mise-nix when MISE_NIX_ALLOW_UNFREE=true
      When call mise install nix:discord
      The status should be success
      The output should include "Successfully installed discord"
    End
  End

  Describe "Insecure Packages"
    # Note: Insecure packages change over time based on CVEs
    # These tests verify the env var mechanism works

    It "can install with NIXPKGS_ALLOW_INSECURE=1 (impure mode enabled)"
      export NIXPKGS_ALLOW_INSECURE=1
      # Use a regular package to verify impure mode doesn't break normal installs
      When call mise install nix:hello
      The status should be success
      The output should include "Successfully installed hello"
    End

    It "can install with MISE_NIX_ALLOW_INSECURE=true (auto-sets NIXPKGS)"
      export MISE_NIX_ALLOW_INSECURE=true
      # NIXPKGS_ALLOW_INSECURE is auto-set by mise-nix
      When call mise install nix:hello
      The status should be success
      The output should include "Successfully installed hello"
    End
  End

  Describe "Local Flakes (Experimental)"
    It "blocks local flakes when disabled"
      Skip if "Local flakes are enabled" [ "${MISE_NIX_ALLOW_LOCAL_FLAKES}" = "true" ]
      
      When call mise install "nix:mytool@./my-project"
      The status should be failure
      The error should include "Package not found: mytool"
    End

    It "allows local flakes when enabled"
      Skip if "Local flakes are disabled" [ "${MISE_NIX_ALLOW_LOCAL_FLAKES}" != "true" ]
      
      # Create a simple test flake directory and file
      BeforeCall create_test_flake
      
      When call mise install "nix:mytool@/tmp/mise-test-flake"
      The status should be success
      The output should include "WARNING: Using local flake"
      
      AfterCall cleanup_test_flake
    End
  End
End