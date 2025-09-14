-- mise-nix installer (modular refactored version)
-- Main installation hook - delegates to specialized modules

local platform = require("platform")
local vscode = require("vscode")
local jetbrains = require("jetbrains")
local flake = require("flake")
local install = require("install")
local vsix = require("vsix")

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

  elseif jetbrains.is_plugin(tool) then
    -- JetBrains plugins: build flake reference to nix-jetbrains-plugins
    local plugin_info = jetbrains.extract_plugin_info(tool)
    if plugin_info then
      -- Build the flake reference based on the nix-jetbrains-plugins structure
      -- The correct path is: plugins.<system>.<ide>.<version>."<plugin_id>"
      local flake_ref = string.format("github:theCapypara/nix-jetbrains-plugins#plugins.%s.%s.\"%s\".\"%s\"",
        plugin_info.system, plugin_info.ide, plugin_info.version, plugin_info.plugin_id)
      -- Build the plugin and then install it to the JetBrains plugin directory
      local build_result = vsix.from_flake(flake_ref, "")
      local nix_store_path = vsix.choose_best_output(build_result.outputs, flake_ref)
      platform.verify_build(nix_store_path, flake_ref)
      jetbrains.install_plugin_from_store(nix_store_path, tool)
      result = {
        version = build_result.version,
        store_path = nix_store_path,
        is_jetbrains = true
      }
    else
      error("Invalid JetBrains plugin format: " .. tool)
    end

  elseif flake.is_reference(tool) then
    result = install.from_flake(tool, requested_version, install_path)

  elseif flake.is_reference(requested_version) then
    result = install.from_flake(requested_version, "", install_path)

  else
    result = install.from_nixhub(tool, requested_version, install_path)
  end

  return { version = result.version }
end