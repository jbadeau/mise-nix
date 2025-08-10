-- mise-nix installer (modular refactored version)
-- Main installation hook - delegates to specialized modules

local platform = require("platform")
local vscode = require("vscode")
local flake = require("flake")
local install = require("install")

function PLUGIN:BackendInstall(ctx)
  local tool = ctx.tool
  local requested_version = ctx.version
  local install_path = ctx.install_path

  platform.check_nix_available()

  local result

  -- Route to appropriate installation strategy
  if vscode.is_extension(tool) then
    -- VSCode extensions: treat as flake references
    local flake_ref = tool:match("^vscode%-extensions%.") and ("nixpkgs#" .. tool) or tool
    result = install.from_flake(flake_ref, requested_version, install_path)
    
  elseif flake.is_reference(tool) then
    result = install.from_flake(tool, requested_version, install_path)
    
  elseif flake.is_reference(requested_version) then
    result = install.from_flake(requested_version, "", install_path)
    
  else
    result = install.from_nixhub(tool, requested_version, install_path)
  end

  return { version = result.version }
end