-- Shell execution utilities with better error handling
local cmd = require("cmd")

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

-- Force create symlink by removing target first (PVC-optimized)
function M.symlink_force(src, dst)
  -- Batch operations to reduce PVC I/O overhead
  M.exec('rm -rf "%s" && ln -sfn "%s" "%s"', dst, src, dst)
end

-- Batch create multiple symlinks (for PVC performance)
function M.symlink_batch(operations)
  if not operations or #operations == 0 then return end
  
  local commands = {}
  for _, op in ipairs(operations) do
    table.insert(commands, string.format('rm -rf "%s" && ln -sfn "%s" "%s"', op.dst, op.src, op.dst))
  end
  
  -- Execute all operations in a single shell command
  M.exec(table.concat(commands, ' && '))
end

-- Check if running in containerized environment (K8s/PVC)
function M.is_containerized()
  return os.getenv("KUBERNETES_SERVICE_HOST") ~= nil or 
         os.getenv("CONTAINER") ~= nil or
         M.try_exec("test -f /.dockerenv")
end

return M