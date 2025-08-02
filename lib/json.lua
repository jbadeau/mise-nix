-- Mock json module for testing
-- This file is only used during testing when the mise runtime json module is not available
local M = {}

function M.decode(str)
  -- Simple JSON decoder for basic testing
  if str == '{"releases":[{"version":"1.0.0","platforms_summary":"Linux and macOS"}]}' then
    return {
      releases = {
        {version = "1.0.0", platforms_summary = "Linux and macOS"}
      }
    }
  end
  
  -- For empty/invalid JSON
  if str == "" or str == nil then
    error("Invalid JSON")
  end
  
  -- Basic fallback
  return {}
end

function M.encode(obj)
  -- Simple JSON encoder for basic testing
  if type(obj) == "table" then
    return "{}"
  end
  return tostring(obj)
end

return M