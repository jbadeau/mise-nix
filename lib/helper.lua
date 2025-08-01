local M = {}

function M.normalize_os(os)
  os = os:lower()
  if os == "darwin" then return "macos"
  elseif os == "linux" then return "linux"
  elseif os == "windows" then return "windows"
  else return os
  end
end

function M.is_compatible(summary, os, arch)
  summary = (summary or ""):lower()
  if not summary:find(os, 1, true) then return false end
  if summary:find("intel only", 1, true) and arch == "arm64" then return false end
  if summary:find("arm only", 1, true) and arch == "amd64" then return false end
  return true
end

function M.is_valid_version(version)
  if type(version) ~= "string" or version == "" then return false end
  return version:match("^[%w%.%-]+$") ~= nil
end

function M.get_nixhub_base_url()
  return os.getenv("MISE_NIX_NIXHUB_BASE_URL") or "https://www.nixhub.io"
end

function M.get_nixpkgs_repo_url()
  return os.getenv("MISE_NIX_NIXPKGS_REPO_URL") or "https://github.com/NixOS/nixpkgs"
end

function M.get_cache_path(tool)
  local cmd = require("cmd")
  local cache_dir = os.getenv("HOME") .. "/.cache/mise-nix"
  cmd.exec("mkdir -p " .. cache_dir)
  return cache_dir .. "/" .. tool .. ".json"
end

function M.fetch_tool_metadata(tool)
  local cmd = require("cmd")
  local json = require("json")
  local url = M.get_nixhub_base_url() .. "/packages/" .. tool .. "?_data=routes%2F_nixhub.packages.%24pkg._index"

  -- Add timeout and better error handling
  local response = cmd.exec("curl -sL --max-time 10 --retry 2 \"" .. url .. "\"")

  if response:match("^curl:") or response == "" then
    return false, nil, "Failed to fetch package metadata from nixhub.io"
  end

  local success, data = pcall(json.decode, response)
  return success, data, response
end

function M.fetch_tool_metadata_cached(tool, max_age_seconds)
  local cmd = require("cmd")
  local json = require("json")
  local cache_file = M.get_cache_path(tool)

  -- Check if cache exists and is fresh
  local stat = cmd.exec("stat -c %Y " .. cache_file .. " 2>/dev/null || echo 0")
  local cache_time = tonumber(stat) or 0

  if os.time() - cache_time < (max_age_seconds or 3600) then
    local cached = cmd.exec("cat " .. cache_file .. " 2>/dev/null")
    if cached and cached ~= "" then
      local success, data = pcall(json.decode, cached)
      if success then return success, data, cached end
    end
  end

  -- Fetch fresh data and cache it
  local success, data, response = M.fetch_tool_metadata(tool)
  if success then
    cmd.exec("echo '" .. response:gsub("'", "'\"'\"'") .. "' > " .. cache_file)
  end
  return success, data, response
end

function M.validate_tool_metadata(success, data, tool, response)
  if not success or not data or not data.releases then
    error("Tool not found or missing releases: " .. tool .. "\nResponse:\n" .. (response or ""))
  end
end

function M.parse_semver(version)
  local major, minor, patch, pre = version:match("^(%d+)%.(%d+)%.(%d+)[%-%.]?(.*)$")
  return {
    major = tonumber(major) or 0,
    minor = tonumber(minor) or 0,
    patch = tonumber(patch) or 0,
    pre = pre or ""
  }
end

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

function M.filter_compatible_versions(releases, os, arch)
  local filtered = {}
  for _, release in ipairs(releases) do
    if M.is_compatible(release.platforms_summary, os, arch) then
      table.insert(filtered, release)
    end
  end
  return filtered
end

function M.find_latest_stable(versions)
  for i = #versions, 1, -1 do
    local parsed = M.parse_semver(versions[i])
    if parsed.pre == "" then
      return versions[i]
    end
  end
  return versions[#versions] -- fallback to actual latest
end

function M.choose_store_path_with_bin(outputs)
  local cmd = require("cmd")
  local candidates = {}

  for _, path in ipairs(outputs) do
    local bin_path = path .. "/bin"
    local has_bin = cmd.exec("test -d '" .. bin_path .. "' && echo yes || echo no"):match("yes")
    local bin_count = 0

    if has_bin then
      bin_count = tonumber(cmd.exec("ls -1 '" .. bin_path .. "' 2>/dev/null | wc -l")) or 0
    end

    table.insert(candidates, {path = path, has_bin = has_bin, bin_count = bin_count})
  end

  -- Prefer output with most binaries, then any with binaries, then first output
  table.sort(candidates, function(a, b)
    if a.has_bin and not b.has_bin then return true end
    if not a.has_bin and b.has_bin then return false end
    return a.bin_count > b.bin_count
  end)

  return candidates[1].path, candidates[1].has_bin
end

function M.check_nix_available()
  local cmd = require("cmd")
  local result = cmd.exec("which nix 2>/dev/null || echo MISSING")
  if result:match("MISSING") then
    error("Nix is not installed or not in PATH. Please install Nix first.")
  end
end

function M.verify_build(chosen_path, tool)
  local cmd = require("cmd")
  -- Check if the path actually exists and is accessible
  local exists = cmd.exec("test -e '" .. chosen_path .. "' && echo yes || echo no"):match("yes")
  if not exists then
    error("Built package path does not exist: " .. chosen_path)
  end

  -- Optional: verify expected binaries exist
  local bin_path = chosen_path .. "/bin"
  if cmd.exec("test -d '" .. bin_path .. "' && echo yes || echo no"):match("yes") then
    local binaries = cmd.exec("ls -1 '" .. bin_path .. "' 2>/dev/null")
    print("Installed binaries: " .. binaries:gsub("\n", ", "))
  end
end

return M