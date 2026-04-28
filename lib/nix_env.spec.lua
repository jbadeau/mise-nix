-- Mock dependencies for env tests
local mock_file_contents = {}
local mock_dir_checks = {}
local mock_tool_json = ""

package.loaded["cmd"] = {
  exec = function(command)
    if command == "mise ls --current --installed --json 2>/dev/null" then
      return mock_tool_json
    end

    if command:match("readlink") then
      return "/nix/store/abc-hello/\n"
    end

    -- test -f checks (for cache file)
    local file_path = command:match("test %-f '([^']+)'")
    if file_path then
      if mock_file_contents[file_path] then return "yes" end
      return "no"
    end

    -- test -d checks
    local dir_path = command:match("test %-d '([^']+)'")
    if dir_path then
      if dir_path:match("/bin") then return "yes" end
      if dir_path:match("/share/man") then return "yes" end
      if dir_path:match("/share/info") then return "no" end
      if dir_path:match("/share'") or dir_path:match("/share$") then return "yes" end
      return "no"
    end

    return "no"
  end
}

local shell_exec_capture = nil
package.loaded["shell"] = {
  exec = function(fmt, ...)
    return ""
  end,
  try_exec = function(fmt, ...)
    if shell_exec_capture then
      return shell_exec_capture(fmt, ...)
    end

    -- Handle cat for cache reading
    local args = {...}
    local command = (select("#", ...) > 0) and string.format(fmt, ...) or fmt
    local cat_path = command:match('cat "([^"]+)"')
    if cat_path and mock_file_contents[cat_path] then
      return true, mock_file_contents[cat_path]
    end

    return false, ""
  end
}

package.loaded["platform"] = {
  get_env_prefix = function() return "" end,
  get_impure_flag = function() return "" end
}

package.loaded["logger"] = {
  debug = function(msg) end,
  warn = function(msg) end,
  info = function(msg) end
}

package.loaded["flake"] = {
  is_reference = function(tool)
    if not tool then return false end
    return tool:match("nixpkgs#") or tool:match("github:") or false
  end,
  parse_reference = function(ref)
    return { url = "nixpkgs", attribute = ref:match("#(.+)") or ref, full_ref = ref }
  end
}

package.loaded["json"] = {
  decode = function(str)
    return nil
  end
}

local env = require("nix_env")

describe("env module", function()
  before_each(function()
    mock_file_contents = {}
    mock_tool_json = ""
    shell_exec_capture = nil
  end)

  it("should have all required functions", function()
    assert.is_function(env.get_env_mode)
    assert.is_function(env.parse_print_dev_env_json)
    assert.is_function(env.cache_dev_env)
    assert.is_function(env.load_cached_env)
    assert.is_function(env.fallback_path_env)
    assert.is_function(env.for_context)
  end)

  describe("get_env_mode", function()
    it("should default to auto", function()
      local mode = env.get_env_mode()
      assert.is_string(mode)
    end)
  end)

  describe("parse_print_dev_env_json", function()
    it("should return error for nil input", function()
      local result, err = env.parse_print_dev_env_json(nil)
      assert.is_nil(result)
      assert.equal("empty JSON input", err)
    end)

    it("should return error for empty string", function()
      local result, err = env.parse_print_dev_env_json("")
      assert.is_nil(result)
      assert.equal("empty JSON input", err)
    end)

    it("should parse JAVA_HOME from valid JSON", function()
      package.loaded["json"].decode = function(str)
        return {
          variables = {
            JAVA_HOME = { type = "exported", value = "/nix/store/abc-jdk" },
            PATH = { type = "exported", value = "/nix/store/abc-jdk/bin" },
            SHELL = { type = "exported", value = "/bin/bash" }
          }
        }
      end

      package.loaded["nix_env"] = nil
      local env2 = require("nix_env")

      local result, err = env2.parse_print_dev_env_json('{"variables":{}}')
      assert.is_nil(err)
      assert.is_table(result)

      local found_java = false
      local found_path = false
      for _, v in ipairs(result) do
        if v.key == "JAVA_HOME" then
          found_java = true
          assert.equal("/nix/store/abc-jdk", v.value)
        end
        if v.key == "PATH" then
          found_path = true
          assert.equal("/nix/store/abc-jdk/bin", v.value)
        end
      end
      assert.is_true(found_java)
      assert.is_true(found_path)

      package.loaded["json"].decode = function(str) return nil end
      package.loaded["nix_env"] = nil
    end)

    it("should ignore non-exported variables", function()
      package.loaded["json"].decode = function(str)
        return {
          variables = {
            PATH = { type = "exported", value = "/nix/store/bin" },
            my_func = { type = "var", value = "some_value" },
            another = { type = "array", value = "val1 val2" }
          }
        }
      end

      package.loaded["nix_env"] = nil
      local env2 = require("nix_env")

      local result, err = env2.parse_print_dev_env_json('{}')
      assert.is_nil(err)
      assert.is_table(result)
      assert.equal(1, #result)
      assert.equal("PATH", result[1].key)

      package.loaded["json"].decode = function(str) return nil end
      package.loaded["nix_env"] = nil
    end)

    it("should handle empty variables table", function()
      package.loaded["json"].decode = function(str)
        return { variables = {} }
      end

      package.loaded["nix_env"] = nil
      local env2 = require("nix_env")

      local result, err = env2.parse_print_dev_env_json('{}')
      assert.is_nil(result)
      assert.equal("no exported variables found", err)

      package.loaded["json"].decode = function(str) return nil end
      package.loaded["nix_env"] = nil
    end)

    it("should handle missing variables key", function()
      package.loaded["json"].decode = function(str)
        return { bashFunctions = {} }
      end

      package.loaded["nix_env"] = nil
      local env2 = require("nix_env")

      local result, err = env2.parse_print_dev_env_json('{}')
      assert.is_nil(result)
      assert.equal("no variables in print-dev-env output", err)

      package.loaded["json"].decode = function(str) return nil end
      package.loaded["nix_env"] = nil
    end)

    it("should handle malformed JSON gracefully", function()
      package.loaded["json"].decode = function(str)
        error("parse error")
      end

      package.loaded["nix_env"] = nil
      local env2 = require("nix_env")

      local result, err = env2.parse_print_dev_env_json('not json')
      assert.is_nil(result)
      assert.equal("failed to parse JSON", err)

      package.loaded["json"].decode = function(str) return nil end
      package.loaded["nix_env"] = nil
    end)
  end)

  describe("load_cached_env", function()
    it("should return nil when no cache exists", function()
      package.loaded["nix_env"] = nil
      local env2 = require("nix_env")

      local result, err = env2.load_cached_env("/some/install/path")
      assert.is_nil(result)
      assert.equal("no cached env found", err)

      package.loaded["nix_env"] = nil
    end)

    it("should read cached env from install path", function()
      -- Set up mock: cache file exists and contains valid JSON
      mock_file_contents["/some/install/path.nix-env.json"] = '{"variables":{}}'

      package.loaded["json"].decode = function(str)
        return {
          variables = {
            JAVA_HOME = { type = "exported", value = "/nix/store/jdk" }
          }
        }
      end

      package.loaded["nix_env"] = nil
      local env2 = require("nix_env")

      local result, err = env2.load_cached_env("/some/install/path")
      assert.is_nil(err)
      assert.is_table(result)
      assert.equal(1, #result)
      assert.equal("JAVA_HOME", result[1].key)

      package.loaded["json"].decode = function(str) return nil end
      package.loaded["nix_env"] = nil
    end)

    it("should return nil for nil install path", function()
      package.loaded["nix_env"] = nil
      local env2 = require("nix_env")

      local result, err = env2.load_cached_env(nil)
      assert.is_nil(result)

      package.loaded["nix_env"] = nil
    end)
  end)

  describe("fallback_path_env", function()
    it("should return PATH for install path with bin", function()
      package.loaded["nix_env"] = nil
      local env2 = require("nix_env")

      local result = env2.fallback_path_env("/some/install/path")
      assert.is_table(result)

      local found_path = false
      for _, v in ipairs(result) do
        if v.key == "PATH" then found_path = true end
      end
      assert.is_true(found_path)

      package.loaded["nix_env"] = nil
    end)

    it("should merge MANPATH entries from active nix tools on PATH", function()
      mock_tool_json = '{"nix:git":[{"install_path":"/Users/jbadeau/.local/share/mise/installs/nix-git/2.53.0","active":true}],"nix:jq":[{"install_path":"/Users/jbadeau/.local/share/mise/installs/nix-jq/1.8.1","active":true}],"go":[{"install_path":"/Users/jbadeau/.local/share/mise/installs/go/1.25.9","active":true}]}'
      package.loaded["json"].decode = function(str)
        return {
          ["nix:git"] = {
            { install_path = "/Users/jbadeau/.local/share/mise/installs/nix-git/2.53.0", active = true }
          },
          ["nix:jq"] = {
            { install_path = "/Users/jbadeau/.local/share/mise/installs/nix-jq/1.8.1", active = true }
          },
          ["go"] = {
            { install_path = "/Users/jbadeau/.local/share/mise/installs/go/1.25.9", active = true }
          }
        }
      end

      package.loaded["nix_env"] = nil
      local env2 = require("nix_env")

      local result = env2.fallback_path_env("/Users/jbadeau/.local/share/mise/installs/nix-jq/1.8.1")
      assert.is_table(result)

      local manpath
      for _, v in ipairs(result) do
        if v.key == "MANPATH" then
          manpath = v.value
        end
      end
      assert.is_not_nil(manpath)
      assert.is_true(manpath:match("/Users/jbadeau/.local/share/mise/installs/nix%-git/2.53.0/share/man") ~= nil)
      assert.is_true(manpath:match("/Users/jbadeau/.local/share/mise/installs/nix%-jq/1.8.1/share/man") ~= nil)

      package.loaded["json"].decode = function(str) return nil end
      package.loaded["nix_env"] = nil
    end)

    it("should return empty table for nil input", function()
      package.loaded["nix_env"] = nil
      local env2 = require("nix_env")

      local result = env2.fallback_path_env(nil)
      assert.is_table(result)
      assert.equal(0, #result)

      package.loaded["nix_env"] = nil
    end)

    it("should return empty table for empty string input", function()
      package.loaded["nix_env"] = nil
      local env2 = require("nix_env")

      local result = env2.fallback_path_env("")
      assert.is_table(result)
      assert.equal(0, #result)

      package.loaded["nix_env"] = nil
    end)
  end)

  describe("for_context", function()
    it("should return env vars in path-only mode", function()
      package.loaded["nix_env"] = nil
      local env2 = require("nix_env")
      env2.get_env_mode = function() return "path-only" end

      local ctx = { tool = "hello", install_path = "/some/path" }
      local result = env2.for_context(ctx)
      assert.is_table(result)

      package.loaded["nix_env"] = nil
    end)

    it("should use cached env when available", function()
      mock_file_contents["/some/path.nix-env.json"] = '{"variables":{}}'

      package.loaded["json"].decode = function(str)
        return {
          variables = {
            JAVA_HOME = { type = "exported", value = "/nix/store/jdk" }
          }
        }
      end

      package.loaded["nix_env"] = nil
      local env2 = require("nix_env")
      env2.get_env_mode = function() return "auto" end

      local ctx = { tool = "nixpkgs#jdk", install_path = "/some/path" }
      local result = env2.for_context(ctx)
      assert.is_table(result)

      -- Should contain both PATH (from fallback) and JAVA_HOME (from cache)
      local found_path, found_java = false, false
      for _, v in ipairs(result) do
        if v.key == "PATH" then found_path = true end
        if v.key == "JAVA_HOME" then found_java = true end
      end
      assert.is_true(found_path)
      assert.is_true(found_java)

      package.loaded["json"].decode = function(str) return nil end
      package.loaded["nix_env"] = nil
    end)

    it("should fall back to path env when no cache exists", function()
      package.loaded["nix_env"] = nil
      local env2 = require("nix_env")
      env2.get_env_mode = function() return "auto" end

      local ctx = { tool = "nixpkgs#hello", install_path = "/some/path" }
      local result = env2.for_context(ctx)
      assert.is_table(result)

      local found_path = false
      for _, v in ipairs(result) do
        if v.key == "PATH" then found_path = true end
      end
      assert.is_true(found_path)

      package.loaded["nix_env"] = nil
    end)

    it("should error in dev-env mode when no cache exists", function()
      package.loaded["nix_env"] = nil
      local env2 = require("nix_env")
      env2.get_env_mode = function() return "dev-env" end

      local ctx = { tool = "nixpkgs#jdk", install_path = "/some/path" }
      assert.has_error(function()
        env2.for_context(ctx)
      end)

      package.loaded["nix_env"] = nil
    end)
  end)
end)
