-- Installation strategies for different package types
local platform = require("platform")
local build = require("build")
local vscode = require("vscode")
local shell = require("shell")
local logger = require("logger")

local M = {}

-- Standard tool installation via symlink
function M.standard_tool(nix_store_path, install_path, label)
  logger.tool("Installing as standard tool: " .. label)
  shell.symlink_force(nix_store_path, install_path)
end

-- Flake installation with hash workaround for direct references
function M.flake_with_hash_workaround(nix_store_path, install_path)
  -- WORKAROUND: mise expects a directory named after the nix store hash for direct flake references
  local nix_hash = nix_store_path:match("/nix/store/([^/]+)")
  if not nix_hash then return end
  
  local install_dir = install_path:match("^(.+)/[^/]+$")
  if not install_dir then return end
  
  local hash_path = install_dir .. "/" .. nix_hash
  shell.symlink_force(nix_store_path, hash_path)
end

-- Install from nixhub with automatic version resolution
function M.from_nixhub(tool, requested_version, install_path)
  local current_os = platform.normalize_os(RUNTIME.osType)
  local current_arch = RUNTIME.archType:lower()
  
  local build_result = build.from_nixhub(tool, requested_version, current_os, current_arch)
  local nix_store_path = build.choose_best_output(build_result.outputs, tool)
  
  -- Verify the build succeeded
  platform.verify_build(nix_store_path, tool)

  -- Handle VSCode extensions specially
  if vscode.is_extension(tool) then
    vscode.install_extension(nix_store_path, install_path, tool)
  else
    M.standard_tool(nix_store_path, install_path, tool)
  end

  logger.done(string.format("Successfully installed %s@%s", tool, build_result.version))
  
  return {
    version = build_result.version,
    store_path = nix_store_path,
    is_vscode = vscode.is_extension(tool)
  }
end

-- Install from flake reference
function M.from_flake(flake_ref, version_hint, install_path)
  local build_result = build.from_flake(flake_ref, version_hint)
  local nix_store_path = build.choose_best_output(build_result.outputs, flake_ref)
  
  -- Verify the build succeeded
  platform.verify_build(nix_store_path, flake_ref)

  local is_vscode = vscode.is_extension(flake_ref)

  if is_vscode then
    logger.find("Detected VSCode extension flake: " .. flake_ref)
    vscode.install_extension(nix_store_path, install_path, flake_ref)
  else
    M.standard_tool(nix_store_path, install_path, flake_ref)
    M.flake_with_hash_workaround(nix_store_path, install_path)
  end

  logger.done("Successfully installed " .. build_result.version)

  return {
    version = build_result.version,
    store_path = nix_store_path,
    is_vscode = is_vscode
  }
end

return M