-- Centralized logging with consistent formatting
local M = {}

function M.info(msg)  print("ℹ️ " .. msg) end
function M.step(msg)  print("🔨 " .. msg) end
function M.done(msg)  print("✅ " .. msg) end
function M.warn(msg)  print("⚠️ " .. msg) end
function M.fail(msg)  print("❌ " .. msg) end
function M.pack(msg)  print("📦 " .. msg) end
function M.find(msg)  print("🔍 " .. msg) end
function M.tool(msg)  print("🔧 " .. msg) end
function M.hint(msg)  print("💡 " .. msg) end

return M