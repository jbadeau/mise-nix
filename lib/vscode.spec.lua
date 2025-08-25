-- Mock dependencies for VSCode tests
package.loaded["shell"] = {
  exec = function(cmd) return "" end,
  try_exec = function(cmd)
    -- Mock successful VSIX installation
    if cmd:match("code.*--install%-extension") then
      return true, "Extension 'test.test' was successfully installed."
    end
    -- Mock package.json existence check
    if cmd:match("test %-f.*package%.json") then
      return true, ""
    end
    -- Mock cat command for package.json
    if cmd:match('cat.*package%.json') then
      return true, '{"name":"test","version":"1.0.0","publisher":"test"}'
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
  step = function(msg) end
}

package.loaded["tempdir"] = {
  with_temp_dir = function(prefix, func)
    -- Simulate successful VSIX creation
    return func("/tmp/mock_temp_dir")
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

local vscode = require("vscode")

describe("VSCode module", function()
  it("should have all required functions", function()
    assert.is_function(vscode.is_extension)
    assert.is_function(vscode.extract_extension_id)
    assert.is_function(vscode.get_extensions_dir)
    assert.is_function(vscode.install_via_vsix)
    assert.is_function(vscode.create_and_install_vsix)
    assert.is_function(vscode.install_extension)
  end)

  describe("is_extension", function()
    it("should detect vscode-extensions patterns", function()
      assert.is_true(vscode.is_extension("vscode-extensions.ms-python.python"))
      assert.is_true(vscode.is_extension("vscode-extensions.golang.go"))
    end)

    it("should detect vscode+install patterns", function()
      assert.is_true(vscode.is_extension("vscode+install=vscode-extensions.ms-python.python"))
    end)

    it("should return false for non-extensions", function()
      assert.is_false(vscode.is_extension("nodejs"))
      assert.is_false(vscode.is_extension("python"))
      assert.is_false(vscode.is_extension(nil))
      assert.is_false(vscode.is_extension(""))
    end)
  end)

  describe("extract_extension_id", function()
    it("should extract ID from vscode-extensions format", function()
      local id = vscode.extract_extension_id("vscode-extensions.ms-python.python")
      assert.equal("ms-python.python", id)
    end)

    it("should extract ID from vscode+install format", function()
      local id = vscode.extract_extension_id("vscode+install=vscode-extensions.golang.go")
      assert.equal("golang.go", id)
    end)

    it("should return nil for invalid formats", function()
      assert.is_nil(vscode.extract_extension_id("nodejs"))
      assert.is_nil(vscode.extract_extension_id(""))
      assert.is_nil(vscode.extract_extension_id(nil))
    end)
  end)

  describe("get_extensions_dir", function()
    it("should return a string path", function()
      local dir = vscode.get_extensions_dir()
      assert.is_string(dir)
      assert.match("%.vscode/extensions", dir)
    end)
  end)

  describe("install functions", function()
    it("should not error when calling install functions", function()
      assert.has_no.errors(function()
        vscode.install_via_vsix("/path/to/test.vsix")
      end)

      assert.has_no.errors(function()
        vscode.install_extension("/nix/store/abc", "vscode-extensions.test.test")
      end)
    end)
  end)
end)