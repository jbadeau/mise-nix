local helper = require("helper")

describe("Helper module", function()

  describe("normalize_os", function()
    it("should normalize OS names correctly", function()
      assert.equal("macos", helper.normalize_os("Darwin"))
      assert.equal("linux", helper.normalize_os("LINUX"))
      assert.equal("windows", helper.normalize_os("windows"))
      assert.equal("unknown", helper.normalize_os("unknown"))
    end)
  end)

  describe("is_valid_version", function()
    it("should validate version strings", function()
      assert.is_true(helper.is_valid_version("1.2.3"))
      assert.is_true(helper.is_valid_version("v1.2.3"))
      assert.is_false(helper.is_valid_version(""))
      assert.is_false(helper.is_valid_version(nil))
      assert.is_false(helper.is_valid_version("!invalid"))
    end)
  end)

  describe("is_compatible", function()
    it("should check compatibility correctly", function()
      assert.is_true(helper.is_compatible("Linux and macOS", "macos", "arm64"))
      assert.is_false(helper.is_compatible("macOS (Intel only)", "macos", "arm64"))
      assert.is_false(helper.is_compatible("Linux (ARM only)", "linux", "amd64"))
      assert.is_true(helper.is_compatible("Linux (ARM only)", "linux", "arm64"))
      assert.is_false(helper.is_compatible(nil, "linux", "arm64"))
    end)
  end)

  describe("parse_semver", function()
    it("should parse semantic version with pre-release", function()
      local parsed = helper.parse_semver("1.2.3-alpha")
      assert.equal(1, parsed.major)
      assert.equal(2, parsed.minor)
      assert.equal(3, parsed.patch)
      assert.equal("alpha", parsed.pre)
    end)

    it("should parse semantic version without pre-release", function()
      local parsed = helper.parse_semver("2.0.0")
      assert.equal(2, parsed.major)
      assert.equal(0, parsed.minor)
      assert.equal(0, parsed.patch)
      assert.equal("", parsed.pre)
    end)
  end)

  describe("semver_less_than", function()
    it("should compare semantic versions correctly", function()
      assert.is_true(helper.semver_less_than("1.0.0", "2.0.0"))
      assert.is_true(helper.semver_less_than("1.0.0-alpha", "1.0.0"))
      assert.is_true(helper.semver_less_than("1.0.0-alpha", "1.0.0-beta"))
      assert.is_false(helper.semver_less_than("1.0.0", "1.0.0"))
      assert.is_false(helper.semver_less_than("1.0.1", "1.0.0"))
      assert.is_false(helper.semver_less_than("1.0.0", "1.0.0-alpha"))
    end)
  end)

  describe("semver sort", function()
    it("should sort semantic versions correctly", function()
      local versions = {
        "1.0.0-alpha",
        "1.0.0-beta",
        "1.0.0",
        "1.0.1",
        "2.0.0",
        "0.9.9"
      }
      table.sort(versions, helper.semver_less_than)
      local expected = {
        "0.9.9",
        "1.0.0-alpha",
        "1.0.0-beta",
        "1.0.0",
        "1.0.1",
        "2.0.0"
      }
      for i = 1, #expected do
        assert.equal(expected[i], versions[i])
      end
    end)
  end)

  describe("filter_compatible_versions", function()
    local releases = {
      {version = "1.0.0", platforms_summary = "Linux and macOS"},
      {version = "2.0.0", platforms_summary = "macOS (Intel only)"},
      {version = "3.0.0", platforms_summary = "Linux (ARM only)"}
    }

    it("should filter compatible versions for macos arm64", function()
      local filtered = helper.filter_compatible_versions(releases, "macos", "arm64")
      assert.equal(1, #filtered)
      assert.equal("1.0.0", filtered[1].version)
    end)

    it("should filter compatible versions for linux arm64", function()
      local filtered2 = helper.filter_compatible_versions(releases, "linux", "arm64")
      assert.equal(2, #filtered2)
      assert.equal("1.0.0", filtered2[1].version)
      assert.equal("3.0.0", filtered2[2].version)
    end)
  end)

  describe("find_latest_stable", function()
    it("should find the latest stable version", function()
      local versions = {"1.0.0-alpha", "1.0.0-beta", "1.0.0", "1.1.0-rc1", "2.0.0"}
      assert.equal("2.0.0", helper.find_latest_stable(versions))
    end)

    it("should fallback when no stable version exists", function()
      local versions2 = {"1.0.0-alpha", "1.0.0-beta", "1.1.0-rc1"}
      assert.equal("1.1.0-rc1", helper.find_latest_stable(versions2))
    end)
  end)

  describe("get_nixhub_base_url", function()
    it("should return a valid base URL", function()
      local base_url = helper.get_nixhub_base_url()
      assert.is_true(type(base_url) == "string")
      assert.is_not_nil(base_url:match("^https?://"))
    end)
  end)

  describe("get_nixpkgs_repo_url", function()
    it("should return a GitHub repo URL", function()
      local repo_url = helper.get_nixpkgs_repo_url()
      assert.is_true(type(repo_url) == "string")
      assert.is_not_nil(repo_url:match("github.com"))
    end)
  end)

end)
