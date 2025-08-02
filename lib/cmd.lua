-- Mock cmd module for testing
-- This file is only used during testing when the mise runtime cmd module is not available
local M = {}

function M.exec(command)
  -- Mock implementations for testing
  if command:match("mkdir %-p") then
    return ""
  elseif command:match("stat %-c %%Y") then
    return "0"  -- Return old timestamp to force fresh fetch
  elseif command:match("cat .*/.*%.json") then
    return ""  -- Return empty to force fresh fetch
  elseif command:match("test %-d .*/bin") then
    return "yes"
  elseif command:match("test %-e") then
    return "yes"
  elseif command:match("ls %-1 .*/bin") then
    return "mockbinary"
  elseif command:match("which nix") then
    return "/usr/bin/nix"
  elseif command:match("curl") then
    -- Mock curl response for nixhub
    return '{"releases":[{"version":"1.0.0","platforms_summary":"Linux and macOS"}]}'
  elseif command:match("nix build") then
    return "/nix/store/abc123-package"
  elseif command:match("echo .* >") then
    return ""
  elseif command:match("pwd") then
    return "/mock/current/dir"
  elseif command:match("realpath") then
    -- Mock realpath to simulate safe paths
    local path = command:match("realpath%s+'([^']+)'")
    if path and path:match("^/mock/current/dir") then
      return path
    else
      return "INVALID"
    end
  else
    return ""
  end
end

return M