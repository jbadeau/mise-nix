function PLUGIN:BackendListVersions(ctx)
  local flake = require("flake")
  local platform = require("platform")
  local nixhub = require("nixhub")
  local version = require("version")
  local tool = ctx.tool

  if not tool or tool == "" then
    error("Tool name cannot be empty")
  end

  -- If this is a flake reference, we return available versions for that flake
  if flake.is_reference(tool) then
    local versions = flake.get_versions(tool)
    return { versions = versions }
  end

  -- Use traditional nixhub.io workflow for regular package names
  local current_os = platform.normalize_os(RUNTIME.osType)
  local current_arch = RUNTIME.archType:lower()

  local success, data, response = nixhub.fetch_metadata(tool)
  
  -- Validate tool metadata and throw error if not found
  nixhub.validate_metadata(success, data, tool, response)

  local versions = {}
  for _, release in ipairs(data.releases) do
    local release_version = release.version
    if version.is_valid(release_version)
        and version.is_compatible(release.platforms_summary, current_os, current_arch) then
      table.insert(versions, release_version)
    end
  end

  -- For ls-remote, return empty list if no compatible versions found
  if #versions == 0 then
    return { versions = {} }
  end

  table.sort(versions, version.semver_less_than)

  return { versions = versions }
end