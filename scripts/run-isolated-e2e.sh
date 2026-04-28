#!/usr/bin/env bash
set -euo pipefail

export HOME="${MISE_NIX_E2E_HOME:-/tmp/mise-nix-e2e-home}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-/tmp/mise-nix-e2e-cache}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-/tmp/mise-nix-e2e-config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-/tmp/mise-nix-e2e-data}"
export LUA_PATH="/workspace/lib/?.lua;;"
export CI=true
export MISE_QUIET=1
export MISE_LOG_LEVEL=error
export MISE_LIBGIT2=false
export MISE_GIX=false
export MISE_NIX_ISOLATED_E2E=true

mkdir -p "$HOME" "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME"

cd /workspace

mise settings set experimental true >/dev/null 2>&1 || true
mise plugin link nix /workspace --force

busted -p %.spec%.lua lib
shellspec -f d
