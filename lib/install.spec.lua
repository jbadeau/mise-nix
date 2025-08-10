-- Mock dependencies for install tests
_G.RUNTIME = {
  osType = "Linux",
  archType = "amd64"
}

package.loaded["platform"] = {
  normalize_os = function(os) return os:lower() end,
  verify_build = function(path, tool) end
}

package.loaded["build"] = {
  from_nixhub = function(tool, version, os, arch)
    return {
      tool = tool,
      version = "1.0.0",
      outputs = {"/nix/store/abc"},
      flake_ref = "nixpkgs#" .. tool
    }
  end,
  from_flake = function(flake_ref, version_hint)
    return {
      flake_ref = flake_ref,
      version = "1.0.0",
      outputs = {"/nix/store/def"}
    }
  end,
  choose_best_output = function(outputs, context) return outputs[1] end
}

package.loaded["vscode"] = {
  is_extension = function(tool) return tool and tool:match("vscode%-extensions%.") end,
  install_extension = function(nix_path, install_path, tool) return "ext.id" end
}

package.loaded["shell"] = {
  symlink_force = function(src, dst) end
}

package.loaded["logger"] = {
  tool = function(msg) end,
  done = function(msg) end,
  find = function(msg) end
}

local install = require("install")

describe("Install module", function()
  it("should have all required functions", function()
    assert.is_function(install.standard_tool)
    assert.is_function(install.flake_with_hash_workaround)
    assert.is_function(install.from_nixhub)
    assert.is_function(install.from_flake)
  end)

  describe("standard_tool", function()
    it("should install without error", function()
      assert.has_no.errors(function()
        install.standard_tool("/nix/store/abc", "/usr/local/bin/tool", "nodejs")
      end)
    end)
  end)

  describe("from_nixhub", function()
    it("should install from nixhub", function()
      local result = install.from_nixhub("nodejs", "18.0.0", "/install/path")
      assert.is_table(result)
      assert.equal("1.0.0", result.version)
      assert.equal("/nix/store/abc", result.store_path)
    end)
  end)

  describe("from_flake", function()
    it("should install from flake", function()
      local result = install.from_flake("nixpkgs#hello", "v1.0.0", "/install/path")
      assert.is_table(result)
      assert.equal("1.0.0", result.version)
      assert.equal("/nix/store/def", result.store_path)
    end)
  end)

  describe("flake_with_hash_workaround", function()
    it("should handle workaround without error", function()
      assert.has_no.errors(function()
        install.flake_with_hash_workaround("/nix/store/abc123-tool", "/install/path")
      end)
    end)
  end)
end)