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

-- Force create symlink by removing target first
function M.symlink_force(src, dst)
  M.exec('rm -rf "%s"', dst)
  M.exec('ln -sfn "%s" "%s"', src, dst)
end

return M