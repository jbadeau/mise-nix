-- Temporary directory management optimized for containerized environments
local shell = require("shell")
local logger = require("logger")

local M = {}

-- Get optimal temp directory based on environment
function M.get_temp_dir()
  if shell.is_containerized() then
    -- Use local filesystem in containers to avoid PVC overhead
    return "/tmp"
  else
    -- Use standard temp directory for local development
    return os.getenv("TMPDIR") or "/tmp"
  end
end

-- Create a unique temporary directory with cleanup tracking
function M.create_temp_dir(prefix)
  prefix = prefix or "mise_temp"
  local temp_base = M.get_temp_dir()
  local temp_dir = temp_base .. "/" .. prefix .. "_" .. os.time() .. "_" .. math.random(1000, 9999)
  
  shell.exec('mkdir -p "%s"', temp_dir)
  logger.debug("Created temp directory: " .. temp_dir)
  
  return temp_dir
end

-- Clean up temporary directory with error handling
function M.cleanup_temp_dir(temp_dir)
  if temp_dir and temp_dir:match("^/tmp/") then
    local ok = shell.try_exec('rm -rf "%s"', temp_dir)
    if ok then
      logger.debug("Cleaned up temp directory: " .. temp_dir)
    else
      logger.warn("Failed to clean up temp directory: " .. temp_dir)
    end
  end
end

-- Execute function with automatic temp directory cleanup
function M.with_temp_dir(prefix, func)
  local temp_dir = M.create_temp_dir(prefix)
  local success, result = pcall(func, temp_dir)
  M.cleanup_temp_dir(temp_dir)
  
  if not success then
    error(result)
  end
  
  return result
end

return M