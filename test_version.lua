local version = require("lib/version")

-- Test the is_valid function with different version formats
local test_versions = {
  "17.0.14+7",
  "17.0.14",
  "1.2.3-rc1",
  "2.0.0+build123"
}

for _, v in ipairs(test_versions) do
  print(string.format("Version '%s' is valid: %s", v, tostring(version.is_valid(v))))
end
