-- Mock dependencies for nixhub tests
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

package.loaded["file"] = {
  join_path = function(...)
    local args = {...}
    return table.concat(args, "/")
  end,
  symlink = function(src, dst) end,
  exists = function(path) return true end
}

local nixhub = require("nixhub")

describe("Nixhub module", function()
  it("should have all required functions", function()
    assert.is_function(nixhub.get_base_url)
    assert.is_function(nixhub.fetch_metadata)
    assert.is_function(nixhub.validate_metadata)
  end)

  describe("get_base_url", function()
    it("should return nixhub URL", function()
      local url = nixhub.get_base_url()
      assert.is_string(url)
      assert.match("nixhub%.io", url)
    end)
  end)

  describe("fetch_metadata", function()
    it("should fetch metadata for a tool", function()
      local success, data, response = nixhub.fetch_metadata("nodejs")
      assert.is_true(success)
      assert.is_table(data)
      assert.is_table(data.releases)
    end)
  end)

  describe("validate_metadata", function()
    it("should validate successful metadata", function()
      local data = {releases = {{version = "1.0.0"}}}
      assert.has_no.errors(function()
        nixhub.validate_metadata(true, data, "nodejs", "{}")
      end)
    end)

    it("should error on invalid metadata", function()
      assert.has_error(function()
        nixhub.validate_metadata(false, nil, "nonexistent", "error")
      end)
    end)
  end)
end)