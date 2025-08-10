-- Version resolution, compatibility handling, and semantic versioning
local nixhub = require("nixhub")

local M = {}

-- Validate version string format
function M.is_valid(version)
  if type(version) ~= "string" or version == "" then return false end
  return version:match("^[%w%.%-]+$") ~= nil
end

-- Parse semantic version string into components
function M.parse_semver(version)
  local major, minor, patch, pre = version:match("^(%d+)%.(%d+)%.(%d+)[%-%.]?(.*)$")
  return {
    major = tonumber(major) or 0,
    minor = tonumber(minor) or 0,
    patch = tonumber(patch) or 0,
    pre = pre or ""
  }
end

-- Compare two semantic versions (returns true if a < b)
function M.semver_less_than(a, b)
  local va = M.parse_semver(a)
  local vb = M.parse_semver(b)

  if va.major ~= vb.major then return va.major < vb.major end
  if va.minor ~= vb.minor then return va.minor < vb.minor end
  if va.patch ~= vb.patch then return va.patch < vb.patch end

  if va.pre == "" and vb.pre ~= "" then return false end
  if va.pre ~= "" and vb.pre == "" then return true end
  return va.pre < vb.pre
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
    table.sort(versions, M.semver_less_than)
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
  local success, data, response = nixhub.fetch_metadata_cached(tool, 3600)
  nixhub.validate_metadata(success, data, tool, response)

  local compatible = M.filter_compatible_versions(data.releases, current_os, current_arch)
  if #compatible == 0 then
    error(string.format("No compatible versions found for %s on %s (%s)", tool, current_os, current_arch))
  end

  -- Sort by version
  table.sort(compatible, function(a, b) 
    return M.semver_less_than(a.version, b.version) 
  end)

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