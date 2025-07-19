local utils = require("utils")

local function assert_eq(actual, expected, msg)
  if actual ~= expected then
    error((msg or "Assertion failed") ..
      ": expected [" .. tostring(expected) .. "] but got [" .. tostring(actual) .. "]")
  end
end

print("🔧 Testing normalize_os...")
assert_eq(utils.normalize_os("Darwin"), "macos")
assert_eq(utils.normalize_os("LINUX"), "linux")
assert_eq(utils.normalize_os("windows"), "windows")
assert_eq(utils.normalize_os("unknown"), "unknown")

print("🔧 Testing is_valid_version...")
assert_eq(utils.is_valid_version("1.2.3"), true)
assert_eq(utils.is_valid_version("v1.2.3"), true)
assert_eq(utils.is_valid_version(""), false)
assert_eq(utils.is_valid_version(nil), false)
assert_eq(utils.is_valid_version("!invalid"), false)

print("🔧 Testing is_compatible...")
assert_eq(utils.is_compatible("Linux and macOS", "macos", "arm64"), true)
assert_eq(utils.is_compatible("macOS (Intel only)", "macos", "arm64"), false)
assert_eq(utils.is_compatible("Linux (ARM only)", "linux", "amd64"), false)
assert_eq(utils.is_compatible("Linux (ARM only)", "linux", "arm64"), true)
assert_eq(utils.is_compatible(nil, "linux", "arm64"), false)

print("🔧 Testing semver_less_than...")
assert_eq(utils.semver_less_than("1.0.0", "2.0.0"), true)
assert_eq(utils.semver_less_than("1.0.0-alpha", "1.0.0"), true)
assert_eq(utils.semver_less_than("1.0.0-alpha", "1.0.0-beta"), true)
assert_eq(utils.semver_less_than("1.0.0", "1.0.0"), false)
assert_eq(utils.semver_less_than("1.0.1", "1.0.0"), false)
assert_eq(utils.semver_less_than("1.0.0", "1.0.0-alpha"), false)

print("🔧 Testing semver sort...")
local versions = {
  "1.0.0-alpha",
  "1.0.0-beta",
  "1.0.0",
  "1.0.1",
  "2.0.0",
  "0.9.9"
}
table.sort(versions, utils.semver_less_than)

local expected = {
  "0.9.9",
  "1.0.0-alpha",
  "1.0.0-beta",
  "1.0.0",
  "1.0.1",
  "2.0.0"
}

for i = 1, #expected do
  assert_eq(versions[i], expected[i], "Sort mismatch at index " .. i)
end

print("✅ All tests passed successfully.")
