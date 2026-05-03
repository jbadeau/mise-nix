-- Mock dependencies for install tests
_G.RUNTIME = {
  osType = "Linux",
  archType = "amd64"
}

local symlink_calls = {}
local mkdir_calls = {}
local link_output_calls = {}
local mock_listings = {}
local mock_listings_all = {}
local mock_shell_calls = {}

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
  try_exec = function(fmt, ...)
    local args = {...}
    local command = (select("#", ...) > 0) and string.format(fmt, unpack(args)) or fmt
    table.insert(mock_shell_calls, command)

    local ls_a_dir = command:match('ls %-1A "([^"]+)"')
    if ls_a_dir then
      if mock_listings_all[ls_a_dir] then
        return true, mock_listings_all[ls_a_dir]
      end
      return false, ""
    end

    local ls_dir = command:match('ls %-1 "([^"]+)"')
    if ls_dir then
      if mock_listings[ls_dir] then
        return true, mock_listings[ls_dir]
      end
      return false, ""
    end

    if command:match("^mkdir %-p ") then
      return true, ""
    end
    if command:match("^ln %-s ") then
      local src, dst = command:match('ln %-s "([^"]+)" "([^"]+)"')
      if src and dst then
        table.insert(symlink_calls, { src = src, dst = dst })
      end
      return true, ""
    end

    return false, ""
  end
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
    mock_listings = {}
    mock_listings_all = {}
    mock_shell_calls = {}
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

    it("should use filtered layout when bin/ has hidden wrapper artifacts", function()
      mock_listings_all["/nix/store/abc/bin"] = "adbe\n.adbe-wrapped"
      mock_listings["/nix/store/abc"] = "bin\nshare"
      mock_listings["/nix/store/abc/bin"] = "adbe"

      install.standard_tool("/nix/store/abc", "/install/path", "adbe")

      -- install_path is created as a directory (not a single symlink)
      assert.equal(1, #mkdir_calls)
      assert.equal("/install/path", mkdir_calls[1])

      -- bin/adbe is linked individually; share is symlinked transparently
      local linked = {}
      for _, c in ipairs(symlink_calls) do linked[c.dst] = c.src end
      assert.equal("/nix/store/abc/bin/adbe", linked["/install/path/bin/adbe"])
      assert.equal("/nix/store/abc/share", linked["/install/path/share"])

      -- the hidden wrapper artifact must NOT be linked
      assert.is_nil(linked["/install/path/bin/.adbe-wrapped"])
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

  describe("has_hidden_bin_files", function()
    it("returns false when bin/ has only public entries", function()
      mock_listings_all["/nix/store/abc/bin"] = "foo\nbar"
      assert.is_false(install.has_hidden_bin_files("/nix/store/abc"))
    end)

    it("returns true when bin/ contains a wrapped artifact", function()
      mock_listings_all["/nix/store/abc/bin"] = "adbe\n.adbe-wrapped"
      assert.is_true(install.has_hidden_bin_files("/nix/store/abc"))
    end)

    it("returns true when sbin/ contains a hidden entry", function()
      mock_listings_all["/nix/store/abc/sbin"] = ".hidden"
      assert.is_true(install.has_hidden_bin_files("/nix/store/abc"))
    end)

    it("returns false when no bin/ or sbin/ exists", function()
      assert.is_false(install.has_hidden_bin_files("/nix/store/abc"))
    end)
  end)

  describe("install_filtered", function()
    it("symlinks non-bin entries directly and filters bin/ to non-hidden only", function()
      mock_listings["/nix/store/abc"] = "bin\nshare\nlib"
      mock_listings["/nix/store/abc/bin"] = "adbe"

      install.install_filtered("/nix/store/abc", "/install/path")

      assert.equal(1, #mkdir_calls)
      assert.equal("/install/path", mkdir_calls[1])

      local linked = {}
      for _, c in ipairs(symlink_calls) do linked[c.dst] = c.src end
      assert.equal("/nix/store/abc/bin/adbe", linked["/install/path/bin/adbe"])
      assert.equal("/nix/store/abc/share", linked["/install/path/share"])
      assert.equal("/nix/store/abc/lib", linked["/install/path/lib"])
      assert.is_nil(linked["/install/path/bin/.adbe-wrapped"])
    end)
  end)

  describe("strip_hidden_bins", function()
    it("issues a find -delete for both bin/ and sbin/", function()
      install.strip_hidden_bins("/install/path")

      local saw_bin, saw_sbin = false, false
      for _, c in ipairs(mock_shell_calls) do
        if c:match('find "/install/path/bin"') and c:match('-name "%.%*"') and c:match("-delete") then
          saw_bin = true
        end
        if c:match('find "/install/path/sbin"') and c:match('-name "%.%*"') and c:match("-delete") then
          saw_sbin = true
        end
      end
      assert.is_true(saw_bin)
      assert.is_true(saw_sbin)
    end)
  end)
end)
