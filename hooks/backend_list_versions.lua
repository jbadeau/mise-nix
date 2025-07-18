local cmd = require("cmd")
local json = require("json")

-- Normalize OS names
local function normalize_os(os)
  os = os:lower()
  if os == "darwin" then return "macos"
  elseif os == "linux" then return "linux"
  elseif os == "windows" then return "windows"
  else return os
  end
end

-- Check if a version is valid
local function is_valid_version(version)
  return version and version ~= "" and version:match("^[%w%.%-]+$")
end

-- Check if a release is compatible with current platform
local function is_compatible(summary, os, arch)
  summary = (summary or ""):lower()
  if not summary:find(os, 1, true) then return false end
  if summary:find("intel only", 1, true) and arch == "arm64" then return false end
  if summary:find("arm only", 1, true) and arch == "amd64" then return false end
  return true
end

-- Fetch and parse metadata for a tool
local function fetch_tool_metadata(tool)
  local url = "https://www.nixhub.io/packages/" .. tool .. "?_data=routes%2F_nixhub.packages.%24pkg._index"
  local response = cmd.exec("curl -sL \"" .. url .. "\"")
  local success, data = pcall(json.decode, response)
  if not success or not data or not data.releases or #data.releases == 0 then
    error("Tool not found or missing releases: " .. tool .. "\nResponse:\n" .. response)
  end
  return data
end

function PLUGIN:BackendListVersions(ctx)
  local tool = ctx.tool
  if not tool or tool == "" then
    error("Tool name cannot be empty")
  end

  local os = normalize_os(RUNTIME.osType)
  local arch = RUNTIME.archType:lower()

  local data = fetch_tool_metadata(tool)

  local versions = {}
  for _, release in ipairs(data.releases) do
    local version = release.version
    local summary = release.platforms_summary
    if is_valid_version(version) and is_compatible(summary, os, arch) then
      table.insert(versions, version)
    end
  end

  if #versions == 0 then
    error("No compatible versions found for " .. tool .. " on " .. os .. " (" .. arch .. ")")
  end

  table.sort(versions, function(a, b) return a > b end)
  return { versions = versions }
end
