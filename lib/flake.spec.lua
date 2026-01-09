-- Mock dependencies for flake tests
package.loaded["shell"] = {
  exec = function(cmd) return "/nix/store/abc123" end
}

package.loaded["logger"] = {
  step = function(msg) end
}

package.loaded["security"] = {
  validate_local_flake = function(flake_ref) return true end
}

package.loaded["platform"] = {
  get_impure_flag = function() return "" end,
  get_env_prefix = function() return "" end,
  get_nix_build_prefix = function() return "" end,
  needs_impure_mode = function() return false end
}

local flake = require("flake")

describe("Flake module", function()
  it("should have all required functions", function()
    assert.is_function(flake.is_reference)
    assert.is_function(flake.convert_custom_git_prefix)
    assert.is_function(flake.parse_git_ref_syntax)
    assert.is_function(flake.parse_reference)
    assert.is_function(flake.get_versions)
    assert.is_function(flake.build)
  end)

  describe("is_reference", function()
    it("should detect flake references", function()
      assert.is_true(flake.is_reference("github:owner/repo#package"))
      assert.is_true(flake.is_reference("nixpkgs#hello"))
      assert.is_true(flake.is_reference("vscode-extensions.ms-python.python"))
    end)

    it("should detect https+ workaround prefix", function()
      assert.is_true(flake.is_reference("https+github.com/nixos/nixpkgs.git#hello"))
      assert.is_true(flake.is_reference("https+gitlab.example.com/group/project.git#default"))
    end)

    it("should detect ssh+ workaround prefix", function()
      assert.is_true(flake.is_reference("ssh+git@github.com/nixos/nixpkgs.git#hello"))
      assert.is_true(flake.is_reference("ssh+gitlab.example.com/group/project.git#default"))
    end)

    it("should detect github+ workaround prefix", function()
      assert.is_true(flake.is_reference("github+nixos/nixpkgs#hello"))
      assert.is_true(flake.is_reference("github+owner/repo"))
    end)

    it("should detect gitlab+ workaround prefix", function()
      assert.is_true(flake.is_reference("gitlab+group/project#default"))
      assert.is_true(flake.is_reference("gitlab+owner/repo"))
    end)

    it("should return false for non-flake references", function()
      assert.is_false(flake.is_reference("nodejs"))
      assert.is_false(flake.is_reference(""))
      assert.is_false(flake.is_reference(nil))
    end)
  end)

  describe("convert_custom_git_prefix", function()
    it("should convert https+ to git+https://", function()
      local result = flake.convert_custom_git_prefix("https+github.com/nixos/nixpkgs.git#hello")
      assert.equal("git+https://github.com/nixos/nixpkgs.git#hello", result)
    end)

    it("should convert ssh+ to git+ssh://", function()
      local result = flake.convert_custom_git_prefix("ssh+git@github.com/nixos/nixpkgs.git#hello")
      assert.equal("git+ssh://git@github.com/nixos/nixpkgs.git#hello", result)
    end)

    it("should convert github+ to github:", function()
      local result = flake.convert_custom_git_prefix("github+nixos/nixpkgs#hello")
      assert.equal("github:nixos/nixpkgs#hello", result)
    end)

    it("should convert gitlab+ to gitlab:", function()
      local result = flake.convert_custom_git_prefix("gitlab+group/project#default")
      assert.equal("gitlab:group/project#default", result)
    end)

    it("should pass through standard nix URLs unchanged", function()
      local result = flake.convert_custom_git_prefix("github:nixos/nixpkgs#hello")
      assert.equal("github:nixos/nixpkgs#hello", result)
    end)

    it("should handle nil and empty strings", function()
      assert.is_nil(flake.convert_custom_git_prefix(nil))
      assert.equal("", flake.convert_custom_git_prefix(""))
    end)
  end)

  describe("parse_reference", function()
    it("should parse GitHub flake references", function()
      local parsed = flake.parse_reference("github:owner/repo#package")
      assert.equal("github:owner/repo", parsed.url)
      assert.equal("package", parsed.attribute)
      assert.equal("github:owner/repo#package", parsed.full_ref)
    end)

    it("should handle VSCode extensions", function()
      local parsed = flake.parse_reference("vscode-extensions.ms-python.python")
      assert.equal("nixpkgs", parsed.url)
      assert.equal("vscode-extensions.ms-python.python", parsed.attribute)
    end)
  end)

  describe("get_versions", function()
    it("should return versions for flake", function()
      local versions = flake.get_versions("github:owner/repo#package")
      assert.is_table(versions)
      assert.is_true(#versions > 0)
    end)
  end)
end)