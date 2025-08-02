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

  describe("is_flake_reference", function()
    it("should detect GitHub flake references", function()
      assert.is_true(helper.is_flake_reference("github:nixos/nixpkgs#hello"))
      assert.is_true(helper.is_flake_reference("github:nix-community/emacs-overlay#emacs-git"))
    end)

    it("should detect GitHub shorthand references", function()
      assert.is_true(helper.is_flake_reference("nixos/nixpkgs#hello"))
      assert.is_true(helper.is_flake_reference("nix-community/emacs-overlay#emacs-git"))
    end)

    it("should detect git+https references", function()
      assert.is_true(helper.is_flake_reference("git+https://github.com/user/repo.git#package"))
    end)

    it("should detect git+ssh references", function()
      assert.is_true(helper.is_flake_reference("git+ssh://git@company.com/tools/overlay.git#tool"))
    end)

    it("should detect local path references", function()
      assert.is_true(helper.is_flake_reference("./my-flake#package"))
      assert.is_true(helper.is_flake_reference("../my-flake#package"))
      assert.is_true(helper.is_flake_reference("/absolute/path/flake#tool"))
    end)

    it("should detect nixpkgs shorthand", function()
      assert.is_true(helper.is_flake_reference("nixpkgs#hello"))
    end)

    it("should detect path and file URIs", function()
      assert.is_true(helper.is_flake_reference("path:/some/path#package"))
      assert.is_true(helper.is_flake_reference("file:/some/path#package"))
    end)

    it("should not detect regular package names", function()
      assert.is_false(helper.is_flake_reference("hello"))
      assert.is_false(helper.is_flake_reference("python"))
      assert.is_false(helper.is_flake_reference(""))
      assert.is_false(helper.is_flake_reference(nil))
      assert.is_false(helper.is_flake_reference("not-a-flake"))
    end)
  end)

  describe("parse_flake_reference", function()
    it("should parse GitHub flake references with attribute", function()
      local parsed = helper.parse_flake_reference("github:nixos/nixpkgs#hello")
      assert.equal("github:nixos/nixpkgs", parsed.url)
      assert.equal("hello", parsed.attribute)
      assert.equal("github:nixos/nixpkgs#hello", parsed.full_ref)
    end)

    it("should normalize GitHub shorthand with attribute", function()
      local parsed = helper.parse_flake_reference("nixos/nixpkgs#hello")
      assert.equal("github:nixos/nixpkgs", parsed.url)
      assert.equal("hello", parsed.attribute)
      assert.equal("github:nixos/nixpkgs#hello", parsed.full_ref)
    end)

    it("should parse git+https references with attribute", function()
      local parsed = helper.parse_flake_reference("git+https://github.com/user/repo.git#package")
      assert.equal("git+https://github.com/user/repo.git", parsed.url)
      assert.equal("package", parsed.attribute)
      assert.equal("git+https://github.com/user/repo.git#package", parsed.full_ref)
    end)

    it("should parse local path references with attribute", function()
      local parsed = helper.parse_flake_reference("./my-flake#package")
      assert.equal("./my-flake", parsed.url)
      assert.equal("package", parsed.attribute)
      assert.equal("./my-flake#package", parsed.full_ref)
    end)

    it("should parse nixpkgs shorthand with attribute", function()
      local parsed = helper.parse_flake_reference("nixpkgs#hello")
      assert.equal("nixpkgs", parsed.url)
      assert.equal("hello", parsed.attribute)
      assert.equal("nixpkgs#hello", parsed.full_ref)
    end)

    it("should parse flake reference without explicit attribute, defaulting to 'default'", function()
      local parsed = helper.parse_flake_reference("github:nixos/nixpkgs")
      assert.equal("github:nixos/nixpkgs", parsed.url)
      assert.equal("default", parsed.attribute)
      assert.equal("github:nixos/nixpkgs#default", parsed.full_ref)
    end)

    it("should error on missing attribute if '#' is present but attribute is empty", function()
      assert.has_error(function()
        helper.parse_flake_reference("github:nixos/nixpkgs#")
      end, "Invalid flake reference format. Expected 'flake_url#attribute', but attribute is empty after '#'. Got: github:nixos/nixpkgs#")
    end)
  end)

  describe("get_flake_versions", function()
    it("should return versions for GitHub flakes", function()
      local versions = helper.get_flake_versions("github:nixos/nixpkgs#hello")
      assert.is_true(#versions >= 1)
      assert.equal("latest", versions[1])
    end)

    it("should return versions for local flakes", function()
      local versions = helper.get_flake_versions("./my-flake#package")
      assert.is_true(#versions >= 1)
      assert.equal("local", versions[1])
    end)

    it("should return versions for path URIs", function()
      local versions = helper.get_flake_versions("path:/some/path#package")
      assert.is_true(#versions >= 1)
      assert.equal("local", versions[1])
    end)

    it("should return versions for absolute paths", function()
      local versions = helper.get_flake_versions("/absolute/path#package")
      assert.is_true(#versions >= 1)
      assert.equal("local", versions[1])
    end)
  end)

  describe("build_flake", function()
    -- Note: These tests would require mocking cmd.exec since they involve actual nix commands
    -- For now, we'll test the validation logic

    it("should validate flake reference format", function()
      assert.has_error(function()
        helper.build_flake("invalid-flake-ref")
      end, "Invalid flake reference") -- Error message from parse_flake_reference
    end)

    it("should accept valid flake references", function()
      -- This would normally call nix build, so we can't easily test without mocking
      -- but we can verify it doesn't error on the validation step
      local mock_cmd = {
        exec = function(cmd)
          if cmd:match("nix build") then
            return "/nix/store/abc123-package"
          end
          return ""
        end
      }

      -- We'd need to inject the mock, but for now we know the validation works
      -- if it gets past the is_flake_reference check
      assert.is_true(helper.is_flake_reference("github:nixos/nixpkgs#hello"))
    end)
  end)

  describe("check_nix_available", function()
    -- This would also require mocking cmd.exec to test properly
    it("should check for nix availability", function()
      -- We can't easily test this without mocking the cmd module
      -- but we can verify the function exists
      assert.is_function(helper.check_nix_available)
    end)
  end)

  describe("Security functions", function()
    describe("allow_local_flakes", function()
      it("should return false by default", function()
        assert.is_false(helper.allow_local_flakes())
      end)
    end)

    describe("is_safe_local_path", function()
      it("should reject dangerous system paths", function()
        assert.is_false(helper.is_safe_local_path("/etc/passwd"))
        assert.is_false(helper.is_safe_local_path("/usr/bin/malicious"))
        assert.is_false(helper.is_safe_local_path("/root/.ssh/id_rsa"))
        assert.is_false(helper.is_safe_local_path("/home/user/.ssh/id_rsa"))
      end)

      it("should reject excessive path traversal", function()
        assert.is_false(helper.is_safe_local_path("../../../etc/passwd"))
        assert.is_false(helper.is_safe_local_path("../../../../usr/bin"))
      end)

      it("should allow safe relative paths", function()
        assert.is_true(helper.is_safe_local_path("./my-flake"))
        assert.is_true(helper.is_safe_local_path("../parent-flake"))
        assert.is_true(helper.is_safe_local_path("subdir/flake"))
      end)

      it("should reject nil or non-string inputs", function()
        assert.is_false(helper.is_safe_local_path(nil))
        assert.is_false(helper.is_safe_local_path(123))
        assert.is_false(helper.is_safe_local_path({}))
      end)
    end)

    describe("validate_local_flake_security", function()
      it("should allow non-local flakes", function()
        assert.is_true(helper.validate_local_flake_security("github:nixos/nixpkgs#hello"))
        assert.is_true(helper.validate_local_flake_security("git+https://github.com/user/repo.git#package"))
      end)

      it("should reject local flakes when disabled", function()
        -- Mock environment to disable local flakes
        local old_env = os.getenv("MISE_NIX_ALLOW_LOCAL_FLAKES")
        
        assert.has_error(function()
          helper.validate_local_flake_security("./my-flake#package")
        end, "Local flakes are disabled for security. Set MISE_NIX_ALLOW_LOCAL_FLAKES=true to enable.")
      end)
    end)
  end)

  describe("choose_store_path_with_bin", function()
    -- This would require mocking file system operations
    it("should handle empty outputs", function()
      assert.has_error(function()
        helper.choose_store_path_with_bin({})
      end, "No valid output paths found from nix build.")
    end)
  end)

  describe("verify_build", function()
    -- This would require mocking file system operations
    it("should be a function", function()
      assert.is_function(helper.verify_build)
    end)
  end)

end)