-- Shell execution utilities with better error handling
local cmd = require("cmd")  -- Native mise cmd module
local file = require("file")  -- Native mise file module

local M = {}

-- Execute shell command with formatted arguments
function M.exec(fmt, ...)
  local command = (select("#", ...) > 0) and string.format(fmt, ...) or fmt
  return cmd.exec(command)
end

-- Try to execute shell command, return success status and result
function M.try_exec(fmt, ...)
  local args = {...}
  local unpack = table.unpack or unpack  -- Compatibility with Lua 5.1/5.2
  local ok, result = pcall(function() 
    return M.exec(fmt, unpack(args))
  end)
  return ok, result
end

-- Force create symlink using native file module
function M.symlink_force(src, dst)
  -- Remove target first if it exists, then create symlink
  M.try_exec('rm -rf "%s"', dst)  -- Clean up existing file/symlink
  file.symlink(src, dst)
end

-- Batch create multiple symlinks
function M.symlink_batch(operations)
  if not operations or #operations == 0 then return end

  for _, op in ipairs(operations) do
    M.symlink_force(op.src, op.dst)
  end
end

-- Check if running in containerized environment (K8s/PVC)
function M.is_containerized()
  return os.getenv("KUBERNETES_SERVICE_HOST") ~= nil or 
         os.getenv("CONTAINER") ~= nil or
         M.try_exec("test -f /.dockerenv")
end

return M