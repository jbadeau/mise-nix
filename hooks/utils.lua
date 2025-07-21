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
  return os.getenv("MISE_NIX_NIXPKGS_REPO_URL") or "github:NixOS/nixpkgs"
end

function M.fetch_tool_metadata(tool)
  local cmd = require("cmd")
  local json = require("json")
  local url = M.get_nixhub_base_url() .. "/packages/" .. tool .. "?_data=routes%2F_nixhub.packages.%24pkg._index"
  local response = cmd.exec("curl -sL \"" .. url .. "\"")
  local success, data = pcall(json.decode, response)
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

return M
