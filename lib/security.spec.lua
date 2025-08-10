-- Mock dependencies for security tests
package.loaded["shell"] = {
  exec = function(cmd) 
    if cmd:match("pwd") then
      return "/home/user/project"
    elseif cmd:match("realpath") then
      return "/home/user/project/subdir"
    end
    return ""
  end
}

package.loaded["flake"] = {
  parse_reference = function(flake_ref)
    return {
      url = flake_ref,
      attribute = "default",
      full_ref = flake_ref .. "#default"
    }
  end
}

local security = require("security")

describe("Security module", function()
  it("should have all required functions", function()
    assert.is_function(security.allow_local_flakes)
    assert.is_function(security.is_safe_local_path)
    assert.is_function(security.validate_local_flake)
  end)

  describe("allow_local_flakes", function()
    it("should check environment variable", function()
      local result = security.allow_local_flakes()
      assert.is_boolean(result)
    end)
  end)

  describe("is_safe_local_path", function()
    it("should reject dangerous paths", function()
      assert.is_false(security.is_safe_local_path("/etc/passwd"))
      assert.is_false(security.is_safe_local_path("/usr/bin/sudo"))
      assert.is_false(security.is_safe_local_path(nil))
    end)

    it("should allow safe relative paths", function()
      assert.is_true(security.is_safe_local_path("./subdir"))
      assert.is_true(security.is_safe_local_path("../parent"))
    end)
  end)

  describe("validate_local_flake", function()
    it("should validate flake without error for non-local flakes", function()
      assert.has_no.errors(function()
        security.validate_local_flake("github:owner/repo#package")
      end)
    end)
  end)
end)