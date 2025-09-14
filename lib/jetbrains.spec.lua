-- Mock dependencies for JetBrains tests
package.loaded["shell"] = {
  exec = function(cmd) return "" end,
  try_exec = function(cmd)
    -- Mock plugin directory check
    if cmd:match("test %-d") then
      return true, ""
    end
    -- Mock copying plugin files
    if cmd:match("cp %-r") then
      return true, ""
    end
    -- Mock finding JAR files
    if cmd:match("find.*%.jar") then
      return true, "plugin.jar"
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

-- Mock os.getenv and os.setenv
local original_getenv = os.getenv
local env_vars = {HOME = "/home/user"}

os.getenv = function(name)
  return env_vars[name] or original_getenv(name)
end

local function setenv(name, value)
  env_vars[name] = value
end

-- Tests for JetBrains plugin functionality
local jetbrains = require("jetbrains")

describe("jetbrains plugin detection", function()
  it("detects JetBrains plugin patterns", function()
    assert.is_true(jetbrains.is_plugin("jetbrains-plugins.x86_64-linux.idea-ultimate.2024.3.com.intellij.plugins.watcher"))
    assert.is_true(jetbrains.is_plugin("jetbrains+install=jetbrains-plugins.x86_64-linux.pycharm-professional.2024.2.com.jetbrains.python"))
  end)

  it("rejects non-JetBrains patterns", function()
    assert.is_false(jetbrains.is_plugin("vscode-extensions.ms-python.python"))
    assert.is_false(jetbrains.is_plugin("regular-tool"))
    assert.is_false(jetbrains.is_plugin("nix:jetbrains-plugins.some.thing"))
    assert.is_false(jetbrains.is_plugin(nil))
  end)
end)

describe("jetbrains plugin info extraction", function()
  it("extracts plugin info from standard format", function()
    local info = jetbrains.extract_plugin_info("jetbrains-plugins.x86_64-linux.idea-ultimate.2024.3.com.intellij.plugins.watcher")

    assert.is_not_nil(info)
    assert.are.equal("x86_64-linux", info.system)
    assert.are.equal("idea-ultimate", info.ide)
    assert.are.equal("2024.3", info.version)
    assert.are.equal("com.intellij.plugins.watcher", info.plugin_id)
  end)

  it("extracts plugin info from install format", function()
    local info = jetbrains.extract_plugin_info("jetbrains+install=jetbrains-plugins.aarch64-darwin.webstorm.2024.2.com.jetbrains.typescript")

    assert.is_not_nil(info)
    assert.are.equal("aarch64-darwin", info.system)
    assert.are.equal("webstorm", info.ide)
    assert.are.equal("2024.2", info.version)
    assert.are.equal("com.jetbrains.typescript", info.plugin_id)
  end)

  it("handles complex plugin IDs", function()
    local info = jetbrains.extract_plugin_info("jetbrains-plugins.x86_64-linux.pycharm-professional.2024.3.org.jetbrains.plugins.remote-run")

    assert.is_not_nil(info)
    assert.are.equal("org.jetbrains.plugins.remote-run", info.plugin_id)
  end)

  it("returns nil for invalid formats", function()
    assert.is_nil(jetbrains.extract_plugin_info("vscode-extensions.ms-python.python"))
    assert.is_nil(jetbrains.extract_plugin_info("jetbrains-plugins.incomplete"))
    assert.is_nil(jetbrains.extract_plugin_info(nil))
  end)
end)

describe("jetbrains plugins directory", function()
  it("returns correct directory for known IDEs", function()
    local home = "/home/user"
    setenv("HOME", home)

    assert.are.equal(home .. "/.local/share/JetBrains/IntelliJIdea2024.3/plugins", jetbrains.get_plugins_dir("idea-ultimate", "2024.3"))
    assert.are.equal(home .. "/.local/share/JetBrains/IntelliJIdea2024.3/plugins", jetbrains.get_plugins_dir("idea-community", "2024.3"))
    assert.are.equal(home .. "/.local/share/JetBrains/PyCharm2024.2/plugins", jetbrains.get_plugins_dir("pycharm-professional", "2024.2"))
    assert.are.equal(home .. "/.local/share/JetBrains/PyCharmCE2024.2/plugins", jetbrains.get_plugins_dir("pycharm-community", "2024.2"))
    assert.are.equal(home .. "/.local/share/JetBrains/WebStorm2024.1/plugins", jetbrains.get_plugins_dir("webstorm", "2024.1"))
  end)

  it("handles unknown IDE names", function()
    local home = "/home/user"
    setenv("HOME", home)

    assert.are.equal(home .. "/.local/share/JetBrains/unknown-ide2024.1/plugins", jetbrains.get_plugins_dir("unknown-ide", "2024.1"))
  end)
end)