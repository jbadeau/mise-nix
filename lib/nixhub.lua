-- Nixhub.io API integration for package metadata
local shell = require("shell")
local json = require("json")

local M = {}

-- Get the base URL for nixhub API
function M.get_base_url()
  return os.getenv("MISE_NIX_NIXHUB_BASE_URL") or "https://www.nixhub.io"
end

-- Get cache directory path for a tool
function M.get_cache_path(tool)
  local cache_dir = os.getenv("HOME") .. "/.cache/mise-nix"
  shell.exec("mkdir -p " .. cache_dir)
  return cache_dir .. "/" .. tool .. ".json"
end

-- Fetch tool metadata from nixhub.io
function M.fetch_metadata(tool)
  local url = M.get_base_url() .. "/packages/" .. tool .. "?_data=routes%2F_nixhub.packages.%24pkg._index"

  -- Add timeout and better error handling
  local response = shell.exec("curl -sL --max-time 10 --retry 2 \"" .. url .. "\"")

  if response:match("^curl:") or response == "" then
    return false, nil, "Failed to fetch package metadata from nixhub.io"
  end

  local success, data = pcall(json.decode, response)
  return success, data, response
end

-- Fetch tool metadata with caching
function M.fetch_metadata_cached(tool, max_age_seconds)
  local cache_file = M.get_cache_path(tool)

  -- Check if cache exists and is fresh
  local stat = shell.exec("stat -c %Y " .. cache_file .. " 2>/dev/null || echo 0")
  local cache_time = tonumber(stat) or 0

  if os.time() - cache_time < (max_age_seconds or 3600) then
    local cached = shell.exec("cat " .. cache_file .. " 2>/dev/null")
    if cached and cached ~= "" then
      local success, data = pcall(json.decode, cached)
      if success then return success, data, cached end
    end
  end

  -- Fetch fresh data and cache it
  local success, data, response = M.fetch_metadata(tool)
  if success then
    shell.exec("echo '" .. response:gsub("'", "'\"'\"'") .. "' > " .. cache_file)
  end
  return success, data, response
end

-- Validate that metadata fetch was successful and contains expected data
function M.validate_metadata(success, data, tool, response)
  if not success or not data or not data.releases then
    -- Create a more user-friendly error message
    local error_msg = "Package not found: " .. tool .. " at https://nixhub.io. Search for available packages at https://search.nixos.org/packages"
    
    -- Only include response details if they're meaningful
    if response and response:match("^{") then
      -- It's JSON, try to extract just the message
      local message = response:match('"message":"([^"]+)"')
      if message and message ~= "Unexpected Server Error" then
        error_msg = "Package not found: " .. tool .. " (" .. message .. ") at https://nixhub.io. Search for available packages at https://search.nixos.org/packages"
      end
    elseif response and #response > 0 and #response < 200 then
      -- Short, potentially useful response
      error_msg = "Package not found: " .. tool .. " (" .. response .. ") at https://nixhub.io. Search for available packages at https://search.nixos.org/packages"
    end
    
    error(error_msg)
  end
end

return M