-- Mock nixhub module for version tests
package.loaded["nixhub"] = {
  fetch_metadata = function(tool)
    return true, {
      releases = {
        {version = "1.0.0", platforms = {{}}},
        {version = "1.1.0", platforms = {{}}},
        {version = "2.0.0", platforms = {{}}}
      }
    }, "success"
  end,
  validate_metadata = function(success, data, tool, response) end
}

local version = require("version")

describe("Version module", function()
  it("should have all required functions", function()
    assert.is_function(version.resolve_alias)
    assert.is_function(version.get_compatible_versions)
    assert.is_function(version.resolve_version)
  end)

  describe("resolve_alias", function()
    local sample_releases = {
      {version = "1.0.0"}, {version = "1.1.0"}, {version = "2.0.0"}
    }

    it("should return latest version for nil/empty", function()
      local result = version.resolve_alias(nil, sample_releases)
      assert.equal("2.0.0", result.version)
    end)

    it("should find exact version match", function()
      local result = version.resolve_alias("1.1.0", sample_releases)
      assert.equal("1.1.0", result.version)
    end)

    it("should return nil for non-existent version", function()
      local result = version.resolve_alias("3.0.0", sample_releases)
      assert.is_nil(result)
    end)
  end)

  describe("filter_compatible_versions", function()
    it("should filter versions by compatibility", function()
      local releases = {
        {version = "1.0.0", platforms_summary = "Linux and macOS"},
        {version = "2.0.0", platforms_summary = "Windows only"}
      }
      local compatible = version.filter_compatible_versions(releases, "linux", "amd64")
      assert.equal(1, #compatible)
      assert.equal("1.0.0", compatible[1].version)
    end)
  end)

  describe("compatibility checking", function()
    it("should handle version/semver functions", function()
      assert.is_true(version.is_valid("1.2.3"))
      assert.is_false(version.is_valid(""))
      
      local parsed = version.parse_semver("1.2.3-alpha")
      assert.equal(1, parsed.major)
      assert.equal(2, parsed.minor)
      assert.equal(3, parsed.patch)
      assert.equal("alpha", parsed.pre)
      
      assert.is_true(version.semver_less_than("1.0.0", "2.0.0"))
      assert.is_false(version.semver_less_than("2.0.0", "1.0.0"))
    end)
  end)
end)