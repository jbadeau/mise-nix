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
    End

    It "can install nix:hello@stable (version alias)"
      When call mise install nix:hello@stable
      The status should be success
    End
  End

  Describe "GitHub Sources"
    It "can install from nixpkgs GitHub repository (default branch)"
      When call mise install "nix:hello@github+nixos/nixpkgs#hello"
      The status should be success
    End

    It "can execute hello from GitHub source"
      When call mise exec "nix:hello@github+nixos/nixpkgs#hello" -- hello
      The status should be success
      The output should include "Hello, world!"
    End

    It "can install from specific branch"
      When call mise install "nix:hello@github+nixos/nixpkgs/nixos-unstable#hello"
      The status should be success
    End

    It "can install from specific release/tag"
      When call mise install "nix:hello@github+nixos/nixpkgs?ref=23.11#hello"
      The status should be success
    End

    It "supports GitHub shorthand syntax (alternative)"
      When call mise ls-remote "nix:hello@nixos/nixpkgs#hello"
      The status should be success
      The output should be blank
    End
  End

  Describe "GitLab Sources"
    It "can parse gitlab+ prefix for ls-remote"
      When call mise ls-remote "nix:mytool@gitlab+group/subgroup/project#default"
      The status should be success
    End

    It "can parse nested GitLab groups"
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
      When call mise ls-remote "nix:nurl@https+github.com/nix-community/nurl.git#default"
      The status should be success
    End

    It "can install using https+ workaround syntax"
      Skip if "nurl build fetches crates.io and is too network-sensitive for isolated e2e" [ "${MISE_NIX_ISOLATED_E2E}" = "true" ]
      When call mise install "nix:nurl@https+github.com/nix-community/nurl.git#default"
      The status should be success
    End
  End

  Describe "Unfree Packages"
    It "fails to install unfree package without NIXPKGS_ALLOW_UNFREE"
      Skip if "discord is not available on this Nix system" [ "$(nix_current_system)" != "x86_64-linux" ]
      Skip if "NIXPKGS_ALLOW_UNFREE is set" [ -n "${NIXPKGS_ALLOW_UNFREE}" ]
      Skip if "MISE_NIX_ALLOW_UNFREE is set" [ "${MISE_NIX_ALLOW_UNFREE}" = "true" ]

      When call mise install nix:discord
      The status should be failure
      The error should include "unfree"
    End

    It "can install unfree package with NIXPKGS_ALLOW_UNFREE=1"
      Skip if "discord is not available on this Nix system" [ "$(nix_current_system)" != "x86_64-linux" ]
      export NIXPKGS_ALLOW_UNFREE=1
      When call mise install nix:discord
      The status should be success
    End

    It "can install unfree package with MISE_NIX_ALLOW_UNFREE=true (auto-sets NIXPKGS)"
      Skip if "discord is not available on this Nix system" [ "$(nix_current_system)" != "x86_64-linux" ]
      export MISE_NIX_ALLOW_UNFREE=true
      When call mise install nix:discord
      The status should be success
    End
  End

  Describe "Insecure Packages"
    It "can install with NIXPKGS_ALLOW_INSECURE=1 (impure mode enabled)"
      export NIXPKGS_ALLOW_INSECURE=1
      When call mise install nix:hello
      The status should be success
    End

    It "can install with MISE_NIX_ALLOW_INSECURE=true (auto-sets NIXPKGS)"
      export MISE_NIX_ALLOW_INSECURE=true
      When call mise install nix:hello
      The status should be success
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

      BeforeCall create_test_flake

      When call mise install "nix:mytool@/tmp/mise-test-flake"
      The status should be success
      The error should include "WARNING: Using local flake"

      AfterCall cleanup_test_flake
    End
  End

  Describe "Nix Environment - Java"
    check_java_home() {
      mkdir -p /tmp/mise-test-jdk
      cd /tmp/mise-test-jdk
      mise settings set experimental true 2>/dev/null
      mise use nix:nixpkgs#jdk >/dev/null 2>&1
      mise exec -- sh -c 'echo JAVA_HOME=$JAVA_HOME'
      local rc=$?
      rm -rf /tmp/mise-test-jdk
      return $rc
    }

    It "can install jdk"
      When call mise install nix:nixpkgs#jdk
      The status should be success
    End

    It "can run java -version from jdk"
      When call mise exec nix:nixpkgs#jdk -- java -version
      The status should be success
      The error should include "openjdk version"
    End

    It "exposes JAVA_HOME when activated via mise use"
      When call check_java_home
      The status should be success
      The output should include "JAVA_HOME=/nix/store/"
    End
  End

  Describe "Nix Environment - Go"
    check_goroot() {
      mkdir -p /tmp/mise-test-go
      cd /tmp/mise-test-go
      mise settings set experimental true 2>/dev/null
      mise use nix:nixpkgs#go >/dev/null 2>&1
      mise exec -- sh -c 'echo GOROOT=$GOROOT'
      local rc=$?
      rm -rf /tmp/mise-test-go
      return $rc
    }

    It "can install go"
      When call mise install nix:nixpkgs#go
      The status should be success
    End

    It "can run go version"
      When call mise exec nix:nixpkgs#go -- go version
      The status should be success
      The output should include "go version go"
    End

    It "exposes GOROOT when activated via mise use"
      When call check_goroot
      The status should be success
      The output should include "GOROOT=/nix/store/"
    End
  End

  Describe "Nix Environment - Fallback Modes"
    It "falls back to PATH-only in path-only mode"
      export MISE_NIX_ENV_MODE=path-only
      When call mise exec nix:hello -- hello
      The status should be success
      The output should include "Hello, world!"
    End

    It "works in dev-env mode for flake packages"
      mise install nix:nixpkgs#hello >/dev/null
      export MISE_NIX_ENV_MODE=dev-env
      When call mise exec nix:nixpkgs#hello -- hello
      The status should be success
      The output should include "Hello, world!"
    End

    It "defaults to auto mode"
      When call mise exec nix:hello -- hello
      The status should be success
      The output should include "Hello, world!"
    End

    It "works with explicit auto mode"
      export MISE_NIX_ENV_MODE=auto
      When call mise exec nix:hello -- hello
      The status should be success
      The output should include "Hello, world!"
    End
  End

  Describe "Multi-output Linking - jq"
    It "can install jq"
      When call mise install nix:nixpkgs#jq
      The status should be success
    End

    It "can run jq"
      When call mise exec nix:nixpkgs#jq -- jq --version
      The status should be success
      The output should include "jq-"
    End
  End

  Describe "Multi-output Linking - git (man, docs, completions)"
    It "can install git"
      When call mise install nix:nixpkgs#git
      The status should be success
    End

    It "can run git"
      When call mise exec nix:nixpkgs#git -- git --version
      The status should be success
      The output should include "git version"
    End

    It "exposes MANPATH for git man pages"
      When call mise exec nix:nixpkgs#git -- sh -c 'test -n "$MANPATH" && echo "MANPATH set"'
      The status should be success
      The output should include "MANPATH set"
    End

    It "exposes XDG_DATA_DIRS for share directory"
      When call mise exec nix:nixpkgs#git -- sh -c 'test -n "$XDG_DATA_DIRS" && echo "XDG set"'
      The status should be success
      The output should include "XDG set"
    End
  End

  Describe "Multi-output Linking - gh (shell completions)"
    It "can install gh"
      When call mise install nix:nixpkgs#gh
      The status should be success
    End

    It "can run gh"
      When call mise exec nix:nixpkgs#gh -- gh --version
      The status should be success
      The output should include "gh version"
    End

    It "exposes XDG_DATA_DIRS for shell completions"
      When call mise exec nix:nixpkgs#gh -- sh -c 'test -n "$XDG_DATA_DIRS" && echo "XDG set"'
      The status should be success
      The output should include "XDG set"
    End
  End

  Describe "Multi-output Linking - Dev Profile"
    It "can install openssl with dev profile"
      export MISE_NIX_LINK_PROFILE=dev
      When call mise install nix:nixpkgs#openssl
      The status should be success
    End

    It "can install pkg-config with dev profile"
      export MISE_NIX_LINK_PROFILE=dev
      When call mise install nix:nixpkgs#pkg-config
      The status should be success
    End

    It "runtime profile does not link include or pkgconfig"
      export MISE_NIX_LINK_PROFILE=runtime
      When call mise install nix:nixpkgs#openssl
      The status should be success
    End
  End

  Describe "Custom Link Paths"
    It "respects MISE_NIX_LINK_PATHS override"
      export MISE_NIX_LINK_PATHS="/bin,/share/man"
      When call mise install nix:nixpkgs#jq
      The status should be success
    End
  End
End
