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
end)