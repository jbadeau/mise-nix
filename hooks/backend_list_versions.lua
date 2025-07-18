function PLUGIN:BackendListVersions(ctx)
  local cmd = require("cmd")
  local json = require("json")

  local tool = ctx.tool
  if not tool or tool == "" then
    error("Tool name cannot be empty")
  end

  -- Normalize OS and arch
  local function normalize_os(os)
    os = os:lower()
    if os == "darwin" then return "macos"
    elseif os == "linux" then return "linux"
    elseif os == "windows" then return "windows"
    else return os
    end
  end

  local current_os = normalize_os(RUNTIME.osType)
  local current_arch = RUNTIME.archType:lower()

  -- Fetch tool metadata
  local url = "https://www.nixhub.io/packages/" .. tool .. "?_data=routes%2F_nixhub.packages.%24pkg._index"
  local response = cmd.exec("curl -sL \"" .. url .. "\"")

  local success, data = pcall(json.decode, response)

  if not success then
    error("Tool not found or missing releases: " .. tool)
  end

  if not data or not data.releases or type(data.releases) ~= "table" or #data.releases == 0 then
    error("Tool not found or missing releases: " .. tool)
  end

  -- Helpers
  local function is_valid_version(version)
    return version and version ~= "" and version:match("^[%w%.%-]+$")
  end

  local function is_compatible(summary)
    summary = (summary or ""):lower()

    if not summary:find(current_os, 1, true) then
      return false
    end

    if summary:find("intel only", 1, true) and current_arch == "arm64" then
      return false
    end

    if summary:find("arm only", 1, true) and current_arch == "amd64" then
      return false
    end

    return true
  end

  local versions = {}
  for _, release in ipairs(data.releases) do
    local version = release.version
    local summary = release.platforms_summary
    if is_valid_version(version) and is_compatible(summary) then
      table.insert(versions, version)
    end
  end

  if #versions == 0 then
    error("No compatible versions found for " .. tool .. " on " .. current_os .. " (" .. current_arch .. ")")
  end

  table.sort(versions, function(a, b) return a > b end)

  return { versions = versions }
end
