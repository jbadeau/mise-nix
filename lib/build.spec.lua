-- Mock dependencies for build tests
package.loaded["platform"] = {
  get_nixpkgs_repo_url = function() return "https://github.com/NixOS/nixpkgs" end,
  choose_store_path_with_bin = function(outputs) return outputs[1], true end
}

package.loaded["flake"] = {
  build = function(flake_ref, version_hint) return {"/nix/store/abc"}, "built_ref" end
}

package.loaded["version"] = {
  resolve_version = function(tool, version, os, arch)
    return {
      version = "1.0.0",
      platforms = {{commit_hash = "abc123", attribute_path = "hello"}}
    }
  end
}

package.loaded["shell"] = {
  exec = function(cmd) return "/nix/store/abc123" end
}

package.loaded["logger"] = {
  step = function(msg) end,
  pack = function(msg) end,
  warn = function(msg) end,
  hint = function(msg) end
}

local build = require("build")

describe("Build module", function()
  it("should have all required functions", function()
    assert.is_function(build.from_nixhub)
    assert.is_function(build.from_flake)
    assert.is_function(build.choose_best_output)
  end)

  describe("from_nixhub", function()
    it("should build package from nixhub", function()
      local result = build.from_nixhub("hello", "latest", "linux", "amd64")
      assert.is_table(result)
      assert.equal("hello", result.tool)
      assert.equal("1.0.0", result.version)
      assert.is_table(result.outputs)
    end)
  end)

  describe("from_flake", function()
    it("should build package from flake reference", function()
      local result = build.from_flake("nixpkgs#hello", "v1.0.0")
      assert.is_table(result)
      assert.equal("nixpkgs#hello", result.flake_ref)
      assert.is_table(result.outputs)
    end)
  end)

  describe("choose_best_output", function()
    it("should choose output without error", function()
      local outputs = {"/nix/store/abc"}
      local chosen = build.choose_best_output(outputs, "nodejs")
      assert.equal("/nix/store/abc", chosen)
    end)
  end)
end)