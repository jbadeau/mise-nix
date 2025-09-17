-- Test version validation regex patterns
local test_versions = {
  "17.0.14+7",
  "17.0.14",
  "1.2.3-rc1",
  "2.0.0+build123"
}

-- Old pattern (doesn't support +)
local old_pattern = "^[%w%.%-]+$"
-- New pattern (supports +)
local new_pattern = "^[%w%.%-+]+$"

print("Testing version validation patterns:")
print("=====================================")
for _, v in ipairs(test_versions) do
  local old_match = v:match(old_pattern) ~= nil
  local new_match = v:match(new_pattern) ~= nil
  print(string.format("Version '%s':", v))
  print(string.format("  Old pattern: %s", tostring(old_match)))
  print(string.format("  New pattern: %s", tostring(new_match)))
end
