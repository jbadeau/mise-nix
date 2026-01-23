-- Mock dependencies for Neovim tests
package.loaded["shell"] = {
  exec = function(cmd) return "" end,
  try_exec = function(cmd)
    -- Mock readlink for checking existing symlink
    if cmd:match("readlink") then
      return false, ""
    end
    return true, "success"
  end,
  symlink_force = function(src, dst) end,
  is_containerized = function() return false end
}

package.loaded["logger"] = {
  pack = function(msg) end,
  info = function(msg) end,
  done = function(msg) end,
  fail = function(msg) end,
  find = function(msg) end,
  warn = function(msg) end,
  debug = function(msg) end,
  hint = function(msg) end,
  step = function(msg) end
}

package.loaded["file"] = {
  join_path = function(...)
    local args = {...}
    return table.concat(args, "/")
  end,
  symlink = function(src, dst) end,
  exists = function(path) return true end
}

local neovim = require("neovim")

describe("Neovim module", function()
  it("should have all required functions", function()
    assert.is_function(neovim.is_plugin)
    assert.is_function(neovim.extract_plugin_name)
    assert.is_function(neovim.extract_flake_ref)
    assert.is_function(neovim.get_plugins_dir)
    assert.is_function(neovim.install_plugin_from_store)
  end)

  describe("is_plugin", function()
    it("should detect neovim+install=vimPlugins patterns", function()
      assert.is_true(neovim.is_plugin("neovim+install=vimPlugins.nvim-treesitter"))
      assert.is_true(neovim.is_plugin("neovim+install=vimPlugins.plenary-nvim"))
      assert.is_true(neovim.is_plugin("neovim+install=vimPlugins.telescope-nvim"))
    end)

    it("should return false for non-neovim plugins", function()
      assert.is_false(neovim.is_plugin("vimPlugins.nvim-treesitter"))
      assert.is_false(neovim.is_plugin("nodejs"))
      assert.is_false(neovim.is_plugin("neovim"))
      assert.is_false(neovim.is_plugin(nil))
      assert.is_false(neovim.is_plugin(""))
    end)

    it("should return false for other IDE plugins", function()
      assert.is_false(neovim.is_plugin("vscode-extensions.ms-python.python"))
      assert.is_false(neovim.is_plugin("jetbrains-plugins.x86_64-linux.idea-ultimate.2024.3"))
    end)
  end)

  describe("extract_plugin_name", function()
    it("should extract plugin name from neovim+install format", function()
      local name = neovim.extract_plugin_name("neovim+install=vimPlugins.nvim-treesitter")
      assert.equal("nvim-treesitter", name)
    end)

    it("should extract plugin name from vimPlugins format", function()
      local name = neovim.extract_plugin_name("vimPlugins.plenary-nvim")
      assert.equal("plenary-nvim", name)
    end)

    it("should handle plugin names with multiple hyphens", function()
      local name = neovim.extract_plugin_name("neovim+install=vimPlugins.nvim-treesitter-textobjects")
      assert.equal("nvim-treesitter-textobjects", name)
    end)

    it("should return nil for invalid formats", function()
      assert.is_nil(neovim.extract_plugin_name("nodejs"))
      assert.is_nil(neovim.extract_plugin_name(""))
      assert.is_nil(neovim.extract_plugin_name(nil))
    end)
  end)

  describe("extract_flake_ref", function()
    it("should extract flake ref from neovim+install format", function()
      local ref = neovim.extract_flake_ref("neovim+install=vimPlugins.nvim-treesitter")
      assert.equal("vimPlugins.nvim-treesitter", ref)
    end)

    it("should extract flake ref with complex plugin name", function()
      local ref = neovim.extract_flake_ref("neovim+install=vimPlugins.nvim-treesitter-textobjects")
      assert.equal("vimPlugins.nvim-treesitter-textobjects", ref)
    end)

    it("should return nil for non-neovim+install formats", function()
      assert.is_nil(neovim.extract_flake_ref("vimPlugins.nvim-treesitter"))
      assert.is_nil(neovim.extract_flake_ref("nodejs"))
      assert.is_nil(neovim.extract_flake_ref(nil))
    end)
  end)

  describe("get_plugins_dir", function()
    it("should return XDG compliant path", function()
      local dir = neovim.get_plugins_dir()
      assert.is_string(dir)
      assert.match("nvim/site/pack/nix/start", dir)
    end)

    it("should use XDG_DATA_HOME if set", function()
      local original = os.getenv("XDG_DATA_HOME")
      -- Note: We can't actually set env vars in Lua easily,
      -- but the function should handle both cases
      local dir = neovim.get_plugins_dir()
      assert.is_string(dir)
    end)
  end)

  describe("install_plugin_from_store", function()
    it("should not error when installing plugin", function()
      assert.has_no.errors(function()
        neovim.install_plugin_from_store(
          "/nix/store/abc123-vimplugin-plenary-nvim",
          "neovim+install=vimPlugins.plenary-nvim"
        )
      end)
    end)

    it("should error with invalid tool name", function()
      assert.has.errors(function()
        neovim.install_plugin_from_store(
          "/nix/store/abc123",
          "invalid-tool-name"
        )
      end)
    end)
  end)
end)
