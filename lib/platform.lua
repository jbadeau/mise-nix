-- Platform and system utilities
local shell = require("shell")

local M = {}

-- Detect current operating system
function M.detect_os()
  if RUNTIME and RUNTIME.osType then
    return M.normalize_os(RUNTIME.osType)
  else
    -- Fallback for cases where RUNTIME is not available (like testing)
    local uname_ok, uname_result = shell.try_exec("uname -s")
    if uname_ok and uname_result then
      uname_result = uname_result:gsub("%s+", "")  -- trim whitespace
      return M.normalize_os(uname_result)
    end

    -- Default fallback to Linux (Windows isn't supported by Nix)
    return "linux"
  end
end

-- Normalize OS names to consistent format
function M.normalize_os(os)
  os = os:lower()
  if os == "darwin" then return "macos"
  elseif os == "linux" then return "linux"
  elseif os == "windows" then return "windows"
  else return os
  end
end

-- Detect current architecture
function M.detect_arch()
  if RUNTIME and RUNTIME.arch then
    return M.normalize_arch(RUNTIME.arch)
  else
    -- Fallback for cases where RUNTIME is not available (like testing)
    local uname_ok, uname_result = shell.try_exec("uname -m")
    if uname_ok and uname_result then
      uname_result = uname_result:gsub("%s+", "")  -- trim whitespace
      return M.normalize_arch(uname_result)
    end

    -- Default fallback to x86_64
    return "x86_64"
  end
end

-- Normalize architecture names to Nix system format
function M.normalize_arch(arch)
  arch = arch:lower()
  if arch == "arm64" or arch == "aarch64" then
    return "aarch64"
  elseif arch == "x86_64" or arch == "amd64" then
    return "x86_64"
  else
    return arch
  end
end

-- Get Nix system identifier (arch-os)
function M.get_nix_system()
  local arch = M.detect_arch()
  local os = M.detect_os()

  -- Convert OS to Nix system format
  if os == "macos" then
    return arch .. "-darwin"
  elseif os == "linux" then
    return arch .. "-linux"
  else
    return arch .. "-" .. os
  end
end

-- Get the nixpkgs repository URL (configurable via environment)
function M.get_nixpkgs_repo_url()
  return os.getenv("MISE_NIX_NIXPKGS_REPO_URL") or "https://github.com/NixOS/nixpkgs"
end

-- Check if impure mode is needed for nix build
-- Supports both native Nix env vars and MISE_NIX_ escape hatches
function M.needs_impure_mode()
  local nixpkgs_unfree = os.getenv("NIXPKGS_ALLOW_UNFREE")
  local nixpkgs_insecure = os.getenv("NIXPKGS_ALLOW_INSECURE")
  local mise_unfree = os.getenv("MISE_NIX_ALLOW_UNFREE") == "true"
  local mise_insecure = os.getenv("MISE_NIX_ALLOW_INSECURE") == "true"

  return mise_unfree or mise_insecure
      or nixpkgs_unfree == "1" or nixpkgs_unfree == "true"
      or nixpkgs_insecure == "1" or nixpkgs_insecure == "true"
end

-- Get environment variable prefix for nix build command
-- Automatically sets NIXPKGS env vars when MISE_NIX ones are used
function M.get_env_prefix()
  local prefix = ""
  local mise_unfree = os.getenv("MISE_NIX_ALLOW_UNFREE") == "true"
  local mise_insecure = os.getenv("MISE_NIX_ALLOW_INSECURE") == "true"

  -- If MISE_NIX env var is set, ensure the corresponding NIXPKGS env var is passed
  if mise_unfree and not os.getenv("NIXPKGS_ALLOW_UNFREE") then
    prefix = prefix .. "NIXPKGS_ALLOW_UNFREE=1 "
  end
  if mise_insecure and not os.getenv("NIXPKGS_ALLOW_INSECURE") then
    prefix = prefix .. "NIXPKGS_ALLOW_INSECURE=1 "
  end

  return prefix
end

-- Get the impure flag for nix build command
function M.get_impure_flag()
  return M.needs_impure_mode() and "--impure " or ""
end

-- Get the full nix build prefix (env vars + impure flag)
function M.get_nix_build_prefix()
  return M.get_env_prefix() .. M.get_impure_flag()
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