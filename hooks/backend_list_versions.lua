function PLUGIN:BackendListVersions(ctx)
  local helper = require("helper")
  local tool = ctx.tool

  if not tool or tool == "" then
    error("Tool name cannot be empty")
  end


  -- If this is a flake reference, we return available versions for that flake
  if helper.is_flake_reference(tool) then
    local versions = helper.get_flake_versions(tool)
    return { versions = versions }
  end

  -- Use traditional nixhub.io workflow for regular package names
  local current_os = helper.normalize_os(RUNTIME.osType)
  local current_arch = RUNTIME.archType:lower()

  local success, data, response = helper.fetch_tool_metadata_cached(tool, 3600)
  
  -- Validate tool metadata and throw error if not found
  helper.validate_tool_metadata(success, data, tool, response)

  local versions = {}
  for _, release in ipairs(data.releases) do
    local version = release.version
    if helper.is_valid_version(version)
        and helper.is_compatible(release.platforms_summary, current_os, current_arch) then
      table.insert(versions, version)
    end
  end

  -- For ls-remote, return empty list if no compatible versions found
  if #versions == 0 then
    return { versions = {} }
  end

  table.sort(versions, helper.semver_less_than)

  return { versions = versions }
end