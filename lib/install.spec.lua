-- Mock dependencies for install tests
_G.RUNTIME = {
  osType = "Linux",
  archType = "amd64"
}

local symlink_calls = {}
local mkdir_calls = {}
local link_output_calls = {}

package.loaded["http"] = {
  get = function(opts)
    return {
      status_code = 200,
      body = '{"releases": [{"version": "1.0.0"}]}'
    }, nil
  end
}

package.loaded["json"] = {
  decode = function(str)
    return {releases = {{version = "1.0.0"}}}
  end
}

package.loaded["cmd"] = {
  exec = function(command)
    return "mocked output"
  end
}

package.loaded["file"] = {
  join_path = function(...)
    local args = {...}
    return table.concat(args, "/")
  end,
  symlink = function(src, dst) end,
  exists = function(path) return true end
}

package.loaded["platform"] = {
  normalize_os = function(os) return os:lower() end,
  verify_build = function(path, tool) end
}

package.loaded["vsix"] = {
  from_nixhub = function(tool, version, os, arch)
    return {
      tool = tool,
      version = "1.0.0",
      outputs = {"/nix/store/abc"},
      flake_ref = "nixpkgs#" .. tool
    }
  end,
  from_flake = function(flake_ref, version_hint)
    local outputs = {"/nix/store/def"}
    if flake_ref == "nixpkgs#multi" then
      outputs = {"/nix/store/multi-bin", "/nix/store/multi-man"}
    end
    return {
      flake_ref = flake_ref,
      version = "1.0.0",
      outputs = outputs
    }
  end,
  choose_best_output = function(outputs, context) return outputs[1] end
}

package.loaded["vscode"] = {
  is_extension = function(tool) return tool and tool:match("vscode%-extensions%.") end,
  install_extension = function(nix_path, install_path, tool) return "ext.id" end
}

package.loaded["shell"] = {
  symlink_force = function(src, dst)
    table.insert(symlink_calls, { src = src, dst = dst })
  end,
  mkdir_force = function(path)
    table.insert(mkdir_calls, path)
  end,
  is_containerized = function() return false end,
  try_exec = function(cmd, ...) return false, "" end
}

package.loaded["logger"] = {
  tool = function(msg) end,
  done = function(msg) end,
  find = function(msg) end,
  debug = function(msg) end
}

package.loaded["output_join"] = {
  link_outputs = function(outputs, install_path)
    table.insert(link_output_calls, { outputs = outputs, install_path = install_path })
    return {}
  end
}

package.loaded["nix_env"] = {
  cache_dev_env = function(flake_ref, install_path) return nil, "mocked" end
}

local install = require("install")

describe("Install module", function()
  before_each(function()
    symlink_calls = {}
    mkdir_calls = {}
    link_output_calls = {}
  end)

  it("should have all required functions", function()
    assert.is_function(install.standard_tool)
    assert.is_function(install.multi_output_tool)
    assert.is_function(install.flake_with_hash_workaround)
    assert.is_function(install.from_nixhub)
    assert.is_function(install.from_flake)
  end)

  describe("standard_tool", function()
    it("should install without error", function()
      assert.has_no.errors(function()
        install.standard_tool("/nix/store/abc", "/usr/local/bin/tool", "nodejs")
      end)
      assert.equal(1, #symlink_calls)
      assert.equal("/nix/store/abc", symlink_calls[1].src)
      assert.equal("/usr/local/bin/tool", symlink_calls[1].dst)
    end)
  end)

  describe("multi_output_tool", function()
    it("should create a writable join directory and link outputs", function()
      install.multi_output_tool(
        {"/nix/store/pkg-bin", "/nix/store/pkg-man"},
        "/install/path",
        "pkg"
      )

      assert.equal(0, #symlink_calls)
      assert.equal(1, #mkdir_calls)
      assert.equal("/install/path", mkdir_calls[1])
      assert.equal(1, #link_output_calls)
      assert.same({"/nix/store/pkg-bin", "/nix/store/pkg-man"}, link_output_calls[1].outputs)
      assert.equal("/install/path", link_output_calls[1].install_path)
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

    it("should use a join directory for multi-output flakes", function()
      local result = install.from_flake("nixpkgs#multi", "v1.0.0", "/install/path")

      assert.is_table(result)
      assert.equal("/nix/store/multi-bin", result.store_path)
      assert.equal(1, #mkdir_calls)
      assert.equal("/install/path", mkdir_calls[1])
      assert.equal(1, #link_output_calls)
      assert.equal(1, #symlink_calls) -- hash workaround only
      assert.equal("/nix/store/multi-bin", symlink_calls[1].src)
      assert.is_not_equal("/install/path", symlink_calls[1].dst)
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
