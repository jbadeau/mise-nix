-- Security functions for local flake handling and validation
local shell = require("shell")

local M = {}

-- Check if local flakes are allowed via environment variable
function M.allow_local_flakes()
  return os.getenv("MISE_NIX_ALLOW_LOCAL_FLAKES") == "true"
end

-- Validate that a local path is safe to use
function M.is_safe_local_path(path)
  -- Only allow paths within current working directory and block dangerous paths
  if not path or type(path) ~= "string" then return false end
  
  -- Block obviously dangerous paths
  local dangerous_patterns = {
    "^/etc/",
    "^/usr/",
    "^/bin/",
    "^/sbin/",
    "^/boot/",
    "^/root/",
    "^/home/[^/]+/%.ssh/",
    "^/home/[^/]+/%.gnupg/",
    "/%.%./"  -- path traversal attempts
  }
  
  for _, pattern in ipairs(dangerous_patterns) do
    if path:match(pattern) then return false end
  end
  
  -- For relative paths, ensure they don't escape the current directory
  if path:match("^%.%.") then
    -- Count directory traversals
    local up_count = 0
    for _ in path:gmatch("%.%./") do
      up_count = up_count + 1
    end
    -- Don't allow going up more than 2 levels to prevent deep traversal
    if up_count > 2 then return false end
  end
  
  -- For absolute paths, check if they're within a safe directory
  if path:match("^/") then
    local cwd = shell.exec("pwd 2>/dev/null || echo '"):gsub("\n", "")
    if cwd == "" then return false end
    
    -- Try to resolve the real path
    local realpath = shell.exec("realpath '" .. path .. "' 2>/dev/null || echo INVALID"):gsub("\n", "")
    if realpath == "INVALID" then return false end
    
    -- Only allow paths within current working directory or its subdirectories
    return realpath:sub(1, #cwd) == cwd
  end
  
  return true
end

-- Validate local flake security before building
function M.validate_local_flake(flake_ref)
  local flake = require("flake")
  local parsed = flake.parse_reference(flake_ref)
  local is_local = parsed.url:match("^%.") or parsed.url:match("^/") or 
                   parsed.url:match("^path:") or parsed.url:match("^file:")
  
  if not is_local then return true end
  
  -- Check if local flakes are allowed
  if not M.allow_local_flakes() then
    error("Local flakes are disabled for security. Set MISE_NIX_ALLOW_LOCAL_FLAKES=true to enable.")
  end
  
  -- Extract path from URL
  local path = parsed.url
  if path:match("^path:") then
    path = path:gsub("^path:", "")
  elseif path:match("^file:") then
    path = path:gsub("^file:", "")
  end
  
  -- Validate the path is safe
  if not M.is_safe_local_path(path) then
    error("Local flake path is not safe: " .. path .. ". Path must be within current working directory and not access sensitive system directories.")
  end
  
  -- Print security warning
  print("⚠️  WARNING: Using local flake - ensure you trust the source: " .. parsed.url)
  print("   Local flakes can execute arbitrary code during evaluation and build.")
  
  return true
end

return M