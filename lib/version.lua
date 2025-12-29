-- Version resolution, compatibility handling, and semantic versioning
local nixhub = require("nixhub")

local M = {}

-- Validate version string format (liberal approach for any package version)
function M.is_valid(version)
  if type(version) ~= "string" or version == "" then return false end
  -- Accept any version string that contains alphanumeric chars and common separators
  -- This covers semantic versions, dates, git hashes, arbitrary tags, etc.
  return version:match("^[%w%.%-+_:~]+$") ~= nil
end

-- Parse version string into comparable components
function M.parse_version(version)
  -- Try standard semantic version first (e.g., "17.0.14", "17.0.14+7")
  local major, minor, patch, pre = version:match("^(%d+)%.(%d+)%.(%d+)[%-%+%.]?(.*)$")
  if major then
    return {
      type = "semantic",
      major = tonumber(major),
      minor = tonumber(minor),
      patch = tonumber(patch),
      pre = pre or "",
      original = version
    }
  end

  -- Try to extract numeric components from various formats
  local numbers = {}
  for num in version:gmatch("%d+") do
    table.insert(numbers, tonumber(num))
  end

  if #numbers >= 1 then
    return {
      type = "numeric",
      major = numbers[1] or 0,
      minor = numbers[2] or 0,
      patch = numbers[3] or 0,
      numbers = numbers,
      original = version
    }
  end

  -- Fallback for non-numeric versions (git hashes, date strings, etc.)
  return {
    type = "string",
    major = 0,
    minor = 0,
    patch = 0,
    original = version
  }
end

-- Keep the old function name for backward compatibility
function M.parse_semver(version)
  local parsed = M.parse_version(version)
  return {
    major = parsed.major,
    minor = parsed.minor,
    patch = parsed.patch,
    pre = parsed.pre or ""
  }
end

-- Find the latest stable version from a list of versions
function M.find_latest_stable(versions)
  for i = #versions, 1, -1 do
    local parsed = M.parse_semver(versions[i])
    if parsed.pre == "" then
      return versions[i]
    end
  end
  return versions[#versions] -- fallback to actual latest
end

-- Check if a release is compatible with the current platform
function M.is_compatible(summary, os, arch)
  summary = (summary or ""):lower()
  if not summary:find(os, 1, true) then return false end
  if summary:find("intel only", 1, true) and arch == "arm64" then return false end
  if summary:find("arm only", 1, true) and arch == "amd64" then return false end
  return true
end

-- Filter releases to only compatible versions
function M.filter_compatible_versions(releases, os, arch)
  local filtered = {}
  for _, release in ipairs(releases) do
    if M.is_compatible(release.platforms_summary, os, arch) then
      table.insert(filtered, release)
    end
  end
  return filtered
end

-- Resolve version aliases to actual releases
function M.resolve_alias(requested_version, compatible_releases)
  if not requested_version or requested_version == "" or requested_version == "latest" then
    return compatible_releases[#compatible_releases]
  end

  if requested_version == "stable" then
    local versions = {}
    for _, release in ipairs(compatible_releases) do
      table.insert(versions, release.version)
    end
    local stable_version = M.find_latest_stable(versions)
    
    for _, release in ipairs(compatible_releases) do
      if release.version == stable_version then
        return release
      end
    end
    return compatible_releases[#compatible_releases] -- fallback
  end

  -- Exact version match
  for _, release in ipairs(compatible_releases) do
    if release.version == requested_version then
      return release
    end
  end

  return nil
end

-- Get and filter compatible versions for current platform
function M.get_compatible_versions(tool, current_os, current_arch)
  local success, data, response = nixhub.fetch_metadata(tool)
  nixhub.validate_metadata(success, data, tool, response)

  local compatible = M.filter_compatible_versions(data.releases, current_os, current_arch)
  if #compatible == 0 then
    error(string.format("No compatible versions found for %s on %s (%s)", tool, current_os, current_arch))
  end

  return compatible, data
end

-- Resolve a specific version from available releases
function M.resolve_version(tool, requested_version, current_os, current_arch)
  local compatible_releases = M.get_compatible_versions(tool, current_os, current_arch)
  
  local release = M.resolve_alias(requested_version, compatible_releases)
  if not release then
    error("Requested version not found or not compatible: " .. tostring(requested_version))
  end
  
  return release
end

return M