-- Simple temporary directory management using native modules
local cmd = require("cmd")
local file = require("file")
local shell = require("shell")

local M = {}

-- Create a unique temporary directory (no cleanup needed)
function M.create_temp_dir(prefix)
  prefix = prefix or "mise_temp"
  local temp_base = os.getenv("TMPDIR") or "/tmp"
  local temp_dir = file.join_path(temp_base, prefix .. "_" .. os.time() .. "_" .. math.random(1000, 9999))

  cmd.exec("mkdir -p " .. temp_dir)

  return temp_dir
end

-- Execute function with temp directory (no cleanup)
function M.with_temp_dir(prefix, func)
  local temp_dir = M.create_temp_dir(prefix)
  return func(temp_dir)
end

return M