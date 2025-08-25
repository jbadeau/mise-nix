-- Mock cmd module for shell tests
package.loaded["cmd"] = {
  exec = function(command) return "mocked: " .. command end
}

package.loaded["file"] = {
  join_path = function(...)
    local args = {...}
    return table.concat(args, "/")
  end,
  symlink = function(src, dst) end,
  exists = function(path) return true end
}

local shell = require("shell")

describe("Shell module", function()
  it("should have all required functions", function()
    assert.is_function(shell.exec)
    assert.is_function(shell.try_exec)
    assert.is_function(shell.symlink_force)
  end)

  it("should execute commands without error", function()
    assert.has_no.errors(function() 
      local result = shell.exec("ls")
      assert.is_string(result)
    end)
  end)

  it("should format commands correctly", function()
    local result = shell.exec("ls %s", "/tmp")
    assert.equal("mocked: ls /tmp", result)
  end)

  it("should handle try_exec without error", function()
    local ok, result = shell.try_exec("pwd")
    assert.is_boolean(ok)
    assert.is_string(result)
  end)

  it("should handle symlink_force without error", function()
    assert.has_no.errors(function()
      shell.symlink_force("/src", "/dst")
    end)
  end)
end)