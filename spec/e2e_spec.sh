Describe "mise-nix plugin"
  Describe "ls-remote command"
    It "returns available versions for nix:helmfile"
      When call mise ls-remote nix:helmfile
      The status should be success
      The output should include "0.140.0"
      The output should include "1.1.3"
    End
  End

  Describe "standard nixpkgs packages"
    It "can install nix:helmfile@1.1.3 (specific version)"
      When call mise install nix:helmfile@1.1.3
      The status should be success
      The output should include "Successfully installed helmfile@1.1.3"
    End

    It "can execute nix:helmfile@1.1.3 after installation"
      When call mise exec nix:helmfile@1.1.3 -- helmfile version
      The status should be success
      The output should include "Version"
      The output should include "v1.1.3"
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

    It "can install nix:nodejs@18.19.0 (specific version)"
      When call mise install nix:nodejs@18.19.0
      The status should be success
      The output should include "Successfully installed nodejs@18.19.0"
    End

    It "can execute nix:nodejs@18.19.0"
      When call mise exec nix:nodejs@18.19.0 -- node --version
      The status should be success
      The output should include "v18.19.0"
    End
  End

  Describe "flake references"
    It "can install flake reference nix:hello@github+nixos/nixpkgs#hello"
      When call mise install "nix:hello@github+nixos/nixpkgs#hello"
      The status should be success
      The output should include "Building flake"
    End

    It "can execute flake reference nix:hello@github+nixos/nixpkgs#hello"
      When call mise exec "nix:hello@github+nixos/nixpkgs#hello" -- hello
      The status should be success
      The output should include "Hello, world!"
    End

    It "returns empty for flake reference ls-remote (no versions)"
      When call mise ls-remote "nix:hello@github+nixos/nixpkgs#hello"
      The status should be success
      The output should be blank
    End
  End

  Describe "VSCode extensions"
    It "recognizes vscode+install= syntax and returns latest"
      When call mise ls-remote "nix:vscode+install=vscode-extensions.golang.go"
      The status should be success
      The output should include "latest"
    End

    It "recognizes direct vscode-extensions syntax and returns latest"
      When call mise ls-remote "nix:vscode-extensions.golang.go"
      The status should be success
      The output should include "latest"
    End
  End

  Describe "error handling"
    It "fails with github: prefix"
      When call mise install nix:hello@github:nixos/nixpkgs#hello
      The status should be failure
      The error should include "invalid prefix: github"
    End

    It "fails with git+https: prefix due to mise parsing"
      When call mise install "nix:hello@git+https://github.com/nixos/nixpkgs.git#hello"
      The status should be failure
      The error should include "invalid prefix: git+https"
    End
  End

  Describe "Git URL syntax"  
    It "supports ssh+ URL syntax for ls-remote"
      When call mise ls-remote "nix:hello@ssh+git@github.com/nixos/nixpkgs.git"
      The status should be success
    End
  End

  Describe "security and local flakes"
    It "blocks local flakes when disabled"
      Skip if "Local flakes are enabled" [ "${MISE_NIX_ALLOW_LOCAL_FLAKES}" = "true" ]
      
      When call mise install "nix:test@./nonexistent#default"
      The status should be failure
      The error should include "Tool not found or missing releases"
    End
  End
End