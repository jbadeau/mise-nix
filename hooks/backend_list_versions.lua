function PLUGIN:BackendListVersions(ctx)
  local utils = require("utils")

  local tool = ctx.tool
  if not tool or tool == "" then
    error("Tool name cannot be empty")
  end

  local current_os = utils.normalize_os(RUNTIME.osType)
  local current_arch = RUNTIME.archType:lower()

  local success, data, response = utils.fetch_tool_metadata(tool)
  utils.validate_tool_metadata(success, data, tool, response)

  local versions = {}
  for _, release in ipairs(data.releases or {}) do
    local version = release.version
    local summary = release.platforms_summary
    if utils.is_valid_version(version) and utils.is_compatible(summary, current_os, current_arch) then
      table.insert(versions, version)
    end
  end

  if #versions == 0 then
    error("No compatible versions found for " .. tool .. " on " .. current_os .. " (" .. current_arch .. ")")
  end

  table.sort(versions, function(a, b) return utils.semver_less_than(a, b) end)

  return { versions = versions }
end
