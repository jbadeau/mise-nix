-- Multi-output linking for Nix packages
-- Links subpaths from nix build outputs into the install directory using link profiles
local shell = require("shell")
local logger = require("logger")

local M = {}

-- Link profiles: controlled sets of subpaths to expose
M.PROFILES = {
  runtime = {
    "bin",
    "sbin",
    "share/man",
    "share/info",
    "share/doc",
    "share/bash-completion",
    "share/zsh",
    "share/fish",
  },
  dev = {
    "bin",
    "sbin",
    "share/man",
    "share/info",
    "share/doc",
    "share/bash-completion",
    "share/zsh",
    "share/fish",
    "include",
    "lib/pkgconfig",
    "share/pkgconfig",
    "share/cmake",
    "share/aclocal",
  },
}

-- Get the active link profile name
function M.get_profile_name()
  return os.getenv("MISE_NIX_LINK_PROFILE") or "runtime"
end

-- Get the list of subpaths to link based on config
-- MISE_NIX_LINK_PATHS overrides the profile entirely
-- MISE_NIX_LINK_PROFILE selects a named profile (default: runtime)
function M.get_link_paths()
  local custom = os.getenv("MISE_NIX_LINK_PATHS")
  if custom and custom ~= "" then
    local paths = {}
    for raw in custom:gmatch("[^,]+") do
      local trimmed = raw:match("^%s*(.-)%s*$")  -- trim whitespace
      if trimmed:sub(1, 1) == "/" then
        trimmed = trimmed:sub(2)  -- strip leading /
      end
      if trimmed ~= "" then
        table.insert(paths, trimmed)
      end
    end
    return paths
  end

  local profile_name = M.get_profile_name()
  local profile = M.PROFILES[profile_name]
  if not profile then
    logger.warn("Unknown MISE_NIX_LINK_PROFILE=" .. profile_name .. ", using runtime")
    profile = M.PROFILES.runtime
  end

  return profile
end

-- Link individual files from src_dir into dst_dir via symlinks
-- Creates dst_dir if it doesn't exist
local function link_dir_contents(src_dir, dst_dir)
  local cmd = require("cmd")

  -- List files/dirs in the source directory
  local ok, listing = shell.try_exec('ls -1 "%s" 2>/dev/null', src_dir)
  if not ok or not listing or listing == "" then
    return 0
  end

  -- Ensure destination directory exists
  shell.try_exec('mkdir -p "%s"', dst_dir)

  local count = 0
  for entry in listing:gmatch("[^\n]+") do
    if entry ~= "" then
      local src = src_dir .. "/" .. entry
      local dst = dst_dir .. "/" .. entry
      -- Only link if target doesn't already exist
      local exists = cmd.exec("test -e '" .. dst .. "' && echo yes || echo no"):match("yes")
      if not exists then
        local link_ok = shell.try_exec('ln -s "%s" "%s"', src, dst)
        if link_ok then
          count = count + 1
        end
      end
    end
  end

  return count
end

-- Link subpaths from all outputs into install_path based on the active profile
-- Returns a table of { subpath = count } for paths that were linked
function M.link_outputs(outputs, install_path)
  if not outputs or #outputs == 0 or not install_path then
    return {}
  end

  local cmd = require("cmd")
  local link_paths = M.get_link_paths()
  local linked = {}

  for _, output_path in ipairs(outputs) do
    for _, subpath in ipairs(link_paths) do
      local src_dir = output_path .. "/" .. subpath
      local has_dir = cmd.exec("test -d '" .. src_dir .. "' && echo yes || echo no"):match("yes")

      if has_dir then
        local dst_dir = install_path .. "/" .. subpath
        local count = link_dir_contents(src_dir, dst_dir)
        if count > 0 then
          linked[subpath] = (linked[subpath] or 0) + count
          logger.debug(string.format("Linked %d entries from %s/%s", count, output_path, subpath))
        end
      end
    end
  end

  return linked
end

return M
