local cmd = require("cmd")
local json = require("json")
local helper = require("helper")

local function resolve_version_alias(requested_version, compatible)
  if requested_version == "latest" or requested_version == "" then
    return compatible[#compatible]
  elseif requested_version == "stable" then
    -- Find latest stable version
    local versions = {}
    for _, release in ipairs(compatible) do
      table.insert(versions, release.version)
    end
    table.sort(versions, helper.semver_less_than)
    local stable_version = helper.find_latest_stable(versions)

    for _, release in ipairs(compatible) do
      if release.version == stable_version then
        return release
      end
    end
    return compatible[#compatible] -- fallback
  else
    -- Exact version match
    for _, release in ipairs(compatible) do
      if release.version == requested_version then
        return release
      end
    end
    return nil
  end
end

function PLUGIN:BackendInstall(ctx)
  local tool = ctx.tool
  local requested_version = ctx.version
  local install_path = ctx.install_path

  -- Check if Nix is available early
  helper.check_nix_available()

  local current_os = helper.normalize_os(RUNTIME.osType)
  local current_arch = RUNTIME.archType:lower()

  -- Use cached metadata for better performance
  local success, data, response = helper.fetch_tool_metadata_cached(tool, 3600) -- 1 hour cache
  helper.validate_tool_metadata(success, data, tool, response)

  local compatible = helper.filter_compatible_versions(data.releases, current_os, current_arch)

  if #compatible == 0 then
    error("No compatible versions found for " .. tool .. " on " .. current_os .. " (" .. current_arch .. ")")
  end

  table.sort(compatible, function(a, b)
    return helper.semver_less_than(a.version, b.version)
  end)

  local target_release = resolve_version_alias(requested_version, compatible)

  if not target_release then
    error("Requested version not found or not compatible: " .. requested_version)
  end

  local platform = target_release.platforms and target_release.platforms[1]
  if not platform then
    error("No platform build found for version " .. target_release.version)
  end

  local nixpkgs_repo = helper.get_nixpkgs_repo_url()
  local ref = string.format("github:NixOS/nixpkgs/%s#%s", platform.commit_hash, platform.attribute_path)
  local cmdline = string.format("nix build --no-link --print-out-paths '%s'", ref)

  print("🔨 Building " .. tool .. "@" .. target_release.version .. "...")
  local result = cmd.exec(cmdline)
  local outputs = {}
  for path in result:gmatch("[^\n]+") do
    table.insert(outputs, path)
  end

  if #outputs == 0 then
    error("No outputs returned by nix build")
  end

  local chosen_path, has_bin = helper.choose_store_path_with_bin(outputs)
  if not has_bin then
    print("⚠️  No binaries found. This package may be a library.")
    print("ℹ️  Falling back to the first available output for linking or use in build environments.")
  end

  -- Verify the build before installing
  helper.verify_build(chosen_path, tool)

  cmd.exec(string.format('rm -rf "%s"', install_path))
  cmd.exec(string.format('ln -sfn "%s" "%s"', chosen_path, install_path))

  print("✅ Successfully installed " .. tool .. "@" .. target_release.version)
  return {}
end