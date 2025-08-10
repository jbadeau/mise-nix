-- Platform and system utilities
local shell = require("shell")

local M = {}

-- Normalize OS names to consistent format
function M.normalize_os(os)
  os = os:lower()
  if os == "darwin" then return "macos"
  elseif os == "linux" then return "linux"
  elseif os == "windows" then return "windows"
  else return os
  end
end

-- Get the nixpkgs repository URL (configurable via environment)
function M.get_nixpkgs_repo_url()
  return os.getenv("MISE_NIX_NIXPKGS_REPO_URL") or "https://github.com/NixOS/nixpkgs"
end

-- Choose the best store path that has binaries
function M.choose_store_path_with_bin(outputs)
  local candidates = {}

  for _, path in ipairs(outputs) do
    local bin_path = path .. "/bin"
    local has_bin = shell.exec("test -d '" .. bin_path .. "' && echo yes || echo no"):match("yes") ~= nil
    local bin_count = 0

    if has_bin then
      bin_count = tonumber(shell.exec("ls -1 '" .. bin_path .. "' 2>/dev/null | wc -l")) or 0
    end

    table.insert(candidates, {path = path, has_bin = has_bin, bin_count = bin_count})
  end

  -- Prefer output with most binaries, then any with binaries, then first output
  table.sort(candidates, function(a, b)
    if a.has_bin and not b.has_bin then return true end
    if not a.has_bin and b.has_bin then return false end
    return a.bin_count > b.bin_count
  end)

  if #candidates == 0 then
      error("No valid output paths found from nix build.")
  end

  return candidates[1].path, candidates[1].has_bin
end

-- Check if Nix is available in PATH
function M.check_nix_available()
  local result = shell.exec("which nix 2>/dev/null || echo MISSING")
  if result:match("MISSING") then
    error("Nix is not installed or not in PATH. Please install Nix first.")
  end
end

-- Verify that a built package path exists and is accessible
function M.verify_build(chosen_path, tool)
  -- Check if the path actually exists and is accessible
  local exists = shell.exec("test -e '" .. chosen_path .. "' && echo yes || echo no"):match("yes")
  if not exists then
    error("Built package path does not exist: " .. chosen_path)
  end

  -- Optional: verify expected binaries exist
  local bin_path = chosen_path .. "/bin"
  local has_bin_dir = shell.exec("test -d '" .. bin_path .. "' && echo yes || echo no"):match("yes")
  if has_bin_dir then
    local binaries = shell.exec("ls -1 '" .. bin_path .. "' 2>/dev/null")
    if binaries and binaries ~= "" then
      print("Installed binaries: " .. binaries:gsub("\n", ", "))
    else
      print("Installed package contains a /bin directory but it is empty.")
    end
  end
end

return M