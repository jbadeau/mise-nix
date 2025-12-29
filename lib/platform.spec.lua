-- Mock dependencies for platform tests
package.loaded["shell"] = {
  exec = function(cmd)
    if cmd:match("test %-d") then
      return "yes"
    elseif cmd:match("ls %-1") then
      return "binary1\nbinary2"
    elseif cmd:match("which nix") then
      return "/usr/bin/nix"
    elseif cmd:match("test %-e") then
      return "yes"
    else
      return ""
    end
  end
}

local platform = require("platform")

describe("Platform module", function()
  it("should have all required functions", function()
    assert.is_function(platform.normalize_os)
    assert.is_function(platform.get_nixpkgs_repo_url)
    assert.is_function(platform.choose_store_path_with_bin)
    assert.is_function(platform.check_nix_available)
    assert.is_function(platform.verify_build)
  end)

  describe("normalize_os", function()
    it("should normalize OS names", function()
      assert.equal("macos", platform.normalize_os("Darwin"))
      assert.equal("linux", platform.normalize_os("LINUX"))
      assert.equal("windows", platform.normalize_os("windows"))
    end)
  end)

  describe("get_nixpkgs_repo_url", function()
    it("should return nixpkgs URL", function()
      local url = platform.get_nixpkgs_repo_url()
      assert.is_string(url)
      assert.match("nixpkgs", url)
    end)
  end)

  describe("choose_store_path_with_bin", function()
    it("should choose path with binaries", function()
      local outputs = {"/nix/store/abc", "/nix/store/def"}
      local path, has_bin = platform.choose_store_path_with_bin(outputs)
      assert.equal("/nix/store/abc", path)
      assert.is_true(has_bin)
    end)
  end)

  describe("check_nix_available", function()
    it("should not error when nix is available", function()
      assert.has_no.errors(function()
        platform.check_nix_available()
      end)
    end)
  end)

  describe("verify_build", function()
    it("should verify build without error", function()
      assert.has_no.errors(function()
        platform.verify_build("/nix/store/abc", "nodejs")
      end)
    end)
  end)

  describe("needs_impure_mode", function()
    it("should be a function", function()
      assert.is_function(platform.needs_impure_mode)
    end)

    it("should return a boolean", function()
      local result = platform.needs_impure_mode()
      assert.is_boolean(result)
    end)

    it("should check NIXPKGS_ALLOW_UNFREE env var", function()
      -- This test documents expected behavior
      -- When NIXPKGS_ALLOW_UNFREE=1, should return true
      local unfree = os.getenv("NIXPKGS_ALLOW_UNFREE")
      if unfree == "1" or unfree == "true" then
        assert.is_true(platform.needs_impure_mode())
      end
    end)

    it("should check NIXPKGS_ALLOW_INSECURE env var", function()
      -- This test documents expected behavior
      -- When NIXPKGS_ALLOW_INSECURE=1, should return true
      local insecure = os.getenv("NIXPKGS_ALLOW_INSECURE")
      if insecure == "1" or insecure == "true" then
        assert.is_true(platform.needs_impure_mode())
      end
    end)

    it("should check MISE_NIX_ALLOW_UNFREE env var", function()
      -- This test documents expected behavior
      -- When MISE_NIX_ALLOW_UNFREE=true, should return true
      local mise_unfree = os.getenv("MISE_NIX_ALLOW_UNFREE")
      if mise_unfree == "true" then
        assert.is_true(platform.needs_impure_mode())
      end
    end)

    it("should check MISE_NIX_ALLOW_INSECURE env var", function()
      -- This test documents expected behavior
      -- When MISE_NIX_ALLOW_INSECURE=true, should return true
      local mise_insecure = os.getenv("MISE_NIX_ALLOW_INSECURE")
      if mise_insecure == "true" then
        assert.is_true(platform.needs_impure_mode())
      end
    end)
  end)

  describe("get_impure_flag", function()
    it("should be a function", function()
      assert.is_function(platform.get_impure_flag)
    end)

    it("should return a string", function()
      local result = platform.get_impure_flag()
      assert.is_string(result)
    end)

    it("should return empty string or --impure flag", function()
      local result = platform.get_impure_flag()
      assert.is_true(result == "" or result == "--impure ")
    end)

    it("should return --impure when needs_impure_mode is true", function()
      if platform.needs_impure_mode() then
        assert.equal("--impure ", platform.get_impure_flag())
      end
    end)

    it("should return empty string when needs_impure_mode is false", function()
      if not platform.needs_impure_mode() then
        assert.equal("", platform.get_impure_flag())
      end
    end)
  end)

  describe("get_env_prefix", function()
    it("should be a function", function()
      assert.is_function(platform.get_env_prefix)
    end)

    it("should return a string", function()
      local result = platform.get_env_prefix()
      assert.is_string(result)
    end)

    it("should include NIXPKGS_ALLOW_UNFREE when MISE_NIX_ALLOW_UNFREE is set", function()
      local mise_unfree = os.getenv("MISE_NIX_ALLOW_UNFREE")
      local nixpkgs_unfree = os.getenv("NIXPKGS_ALLOW_UNFREE")
      if mise_unfree == "true" and not nixpkgs_unfree then
        assert.match("NIXPKGS_ALLOW_UNFREE=1", platform.get_env_prefix())
      end
    end)

    it("should include NIXPKGS_ALLOW_INSECURE when MISE_NIX_ALLOW_INSECURE is set", function()
      local mise_insecure = os.getenv("MISE_NIX_ALLOW_INSECURE")
      local nixpkgs_insecure = os.getenv("NIXPKGS_ALLOW_INSECURE")
      if mise_insecure == "true" and not nixpkgs_insecure then
        assert.match("NIXPKGS_ALLOW_INSECURE=1", platform.get_env_prefix())
      end
    end)
  end)

  describe("get_nix_build_prefix", function()
    it("should be a function", function()
      assert.is_function(platform.get_nix_build_prefix)
    end)

    it("should return a string", function()
      local result = platform.get_nix_build_prefix()
      assert.is_string(result)
    end)

    it("should combine env prefix and impure flag", function()
      local result = platform.get_nix_build_prefix()
      local expected = platform.get_env_prefix() .. platform.get_impure_flag()
      assert.equal(expected, result)
    end)
  end)
end)