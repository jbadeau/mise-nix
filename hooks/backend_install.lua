local cmd = require("cmd")
local json = require("json")
local utils = require("utils")

function PLUGIN:BackendInstall(ctx)
  local tool = ctx.tool
  local requested_version = ctx.version
  local install_path = ctx.install_path

  local current_os = utils.normalize_os(RUNTIME.osType)
  local current_arch = RUNTIME.archType:lower()

  local success, data, response = utils.fetch_tool_metadata(tool)
  utils.validate_tool_metadata(success, data, tool, response)

  local compatible = utils.filter_compatible_versions(data.releases, current_os, current_arch)

  if #compatible == 0 then
    error("No compatible versions found for " .. tool .. " on " .. current_os .. " (" .. current_arch .. ")")
  end

  table.sort(compatible, function(a, b)
    return utils.semver_less_than(a.version, b.version)
  end)

  local target_release = nil
  if requested_version and requested_version ~= "" and requested_version ~= "latest" then
    for _, r in ipairs(compatible) do
      if r.version == requested_version then
        target_release = r
        break
      end
    end
    if not target_release then
      error("Requested version not found or not compatible: " .. requested_version)
    end
  else
    target_release = compatible[#compatible]
  end

  local platform = target_release.platforms and target_release.platforms[1]
  if not platform then
    error("No platform build found for version " .. target_release.version)
  end

  local nixpkgs_repo = utils.get_nixpkgs_repo_url()
  local ref = string.format("github:NixOS/nixpkgs/%s#%s", platform.commit_hash, platform.attribute_path)
  local cmdline = string.format("nix build --no-link --print-out-paths '%s'", ref)

  local result = cmd.exec(cmdline)
  local outputs = {}
  for path in result:gmatch("[^\n]+") do
    table.insert(outputs, path)
  end

  if #outputs == 0 then
    error("No outputs returned by nix build")
  end

  local chosen_path, has_bin = utils.choose_store_path_with_bin(outputs)
  if not has_bin then
    print("⚠️  No bin/ directory found. This package may be a library.")
    print("ℹ️  Falling back to the first available output for linking or use in build environments.")
  end

  cmd.exec(string.format('rm -rf "%s"', install_path))
  cmd.exec(string.format('ln -sfn "%s" "%s"', chosen_path, install_path))

  return {}
end
