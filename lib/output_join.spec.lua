-- Mock dependencies for output_join tests
local mock_dirs = {}
local mock_listings = {}
local mock_exists = {}
local mock_mkdir_calls = {}
local mock_symlink_calls = {}

package.loaded["cmd"] = {
  exec = function(command)
    -- test -d checks
    local dir = command:match("test %-d '([^']+)'")
    if dir then
      if mock_dirs[dir] then
        return "yes"
      end
      return "no"
    end

    -- test -e checks
    local path = command:match("test %-e '([^']+)'")
    if path then
      if mock_exists[path] then
        return "yes"
      end
      return "no"
    end

    return ""
  end
}

package.loaded["shell"] = {
  exec = function(fmt, ...)
    return ""
  end,
  try_exec = function(fmt, ...)
    local args = {...}
    local command = (select("#", ...) > 0) and string.format(fmt, ...) or fmt

    -- ls -1 listing
    local ls_dir = command:match('ls %-1 "([^"]+)"')
    if ls_dir then
      if mock_listings[ls_dir] then
        return true, mock_listings[ls_dir]
      end
      return false, ""
    end

    -- mkdir -p
    local mkdir_dir = command:match('mkdir %-p "([^"]+)"')
    if mkdir_dir then
      table.insert(mock_mkdir_calls, mkdir_dir)
      return true, ""
    end

    -- ln -s
    local src, dst = command:match('ln %-s "([^"]+)" "([^"]+)"')
    if src and dst then
      table.insert(mock_symlink_calls, { src = src, dst = dst })
      return true, ""
    end

    return true, ""
  end
}

package.loaded["logger"] = {
  debug = function(msg) end,
  warn = function(msg) end,
  info = function(msg) end
}

local output_join = require("output_join")

describe("output_join module", function()
  before_each(function()
    mock_dirs = {}
    mock_listings = {}
    mock_exists = {}
    mock_mkdir_calls = {}
    mock_symlink_calls = {}
  end)

  it("should have required functions", function()
    assert.is_function(output_join.link_outputs)
    assert.is_function(output_join.get_link_paths)
    assert.is_function(output_join.get_profile_name)
    assert.is_table(output_join.PROFILES)
  end)

  describe("profiles", function()
    it("should define runtime profile", function()
      local runtime = output_join.PROFILES.runtime
      assert.is_table(runtime)
      assert.is_true(#runtime >= 5)

      local has_bin, has_man, has_doc = false, false, false
      for _, sp in ipairs(runtime) do
        if sp == "bin" then has_bin = true end
        if sp == "share/man" then has_man = true end
        if sp == "share/doc" then has_doc = true end
      end
      assert.is_true(has_bin)
      assert.is_true(has_man)
      assert.is_true(has_doc)
    end)

    it("should define dev profile as superset of runtime", function()
      local dev = output_join.PROFILES.dev
      assert.is_table(dev)
      assert.is_true(#dev > #output_join.PROFILES.runtime)

      local has_include, has_pkgconfig = false, false
      for _, sp in ipairs(dev) do
        if sp == "include" then has_include = true end
        if sp == "lib/pkgconfig" then has_pkgconfig = true end
      end
      assert.is_true(has_include)
      assert.is_true(has_pkgconfig)
    end)

    it("should not include /lib in runtime profile", function()
      local runtime = output_join.PROFILES.runtime
      for _, sp in ipairs(runtime) do
        assert.is_not_equal("lib", sp)
        assert.is_not_equal("include", sp)
        assert.is_not_equal("lib/pkgconfig", sp)
      end
    end)
  end)

  describe("get_link_paths", function()
    it("should return runtime paths by default", function()
      local paths = output_join.get_link_paths()
      assert.is_table(paths)
      assert.is_true(#paths >= 5)
    end)
  end)

  describe("link_outputs", function()
    it("should return empty table for nil outputs", function()
      local result = output_join.link_outputs(nil, "/install")
      assert.same({}, result)
    end)

    it("should return empty table for empty outputs", function()
      local result = output_join.link_outputs({}, "/install")
      assert.same({}, result)
    end)

    it("should return empty table for nil install_path", function()
      local result = output_join.link_outputs({"/nix/store/abc"}, nil)
      assert.same({}, result)
    end)

    it("should link /bin entries from outputs", function()
      mock_dirs["/nix/store/pkg-out/bin"] = true
      mock_listings["/nix/store/pkg-out/bin"] = "foo\nbar"

      local result = output_join.link_outputs(
        {"/nix/store/pkg-out"},
        "/install"
      )

      assert.equal(2, result["bin"])
      assert.equal(1, #mock_mkdir_calls)
      assert.equal("/install/bin", mock_mkdir_calls[1])
      assert.equal(2, #mock_symlink_calls)
    end)

    it("should link /share/man entries from outputs", function()
      mock_dirs["/nix/store/pkg-man/share/man"] = true
      mock_listings["/nix/store/pkg-man/share/man"] = "man1\nman3"

      local result = output_join.link_outputs(
        {"/nix/store/pkg-man"},
        "/install"
      )

      assert.equal(2, result["share/man"])
    end)

    it("should link /share/doc entries from outputs", function()
      mock_dirs["/nix/store/pkg-doc/share/doc"] = true
      mock_listings["/nix/store/pkg-doc/share/doc"] = "readme.txt"

      local result = output_join.link_outputs(
        {"/nix/store/pkg-doc"},
        "/install"
      )

      assert.equal(1, result["share/doc"])
    end)

    it("should ignore missing subpaths", function()
      -- No mock_dirs set, so all test -d checks return "no"
      local result = output_join.link_outputs(
        {"/nix/store/pkg-out"},
        "/install"
      )

      assert.same({}, result)
      assert.equal(0, #mock_symlink_calls)
    end)

    it("should not overwrite existing entries", function()
      mock_dirs["/nix/store/pkg-out/bin"] = true
      mock_listings["/nix/store/pkg-out/bin"] = "foo"
      mock_exists["/install/bin/foo"] = true  -- already exists

      local result = output_join.link_outputs(
        {"/nix/store/pkg-out"},
        "/install"
      )

      -- Should not have linked anything since target exists
      assert.equal(0, #mock_symlink_calls)
    end)

    it("should handle multiple outputs", function()
      mock_dirs["/nix/store/pkg-out/bin"] = true
      mock_dirs["/nix/store/pkg-man/share/man"] = true
      mock_listings["/nix/store/pkg-out/bin"] = "hello"
      mock_listings["/nix/store/pkg-man/share/man"] = "man1"

      local result = output_join.link_outputs(
        {"/nix/store/pkg-out", "/nix/store/pkg-man"},
        "/install"
      )

      assert.equal(1, result["bin"])
      assert.equal(1, result["share/man"])
    end)

    it("should preserve original store paths in symlinks", function()
      mock_dirs["/nix/store/abc-jdk/bin"] = true
      mock_listings["/nix/store/abc-jdk/bin"] = "java"

      output_join.link_outputs(
        {"/nix/store/abc-jdk"},
        "/install"
      )

      assert.equal(1, #mock_symlink_calls)
      assert.equal("/nix/store/abc-jdk/bin/java", mock_symlink_calls[1].src)
      assert.equal("/install/bin/java", mock_symlink_calls[1].dst)
    end)
  end)
end)
