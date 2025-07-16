function PLUGIN:BackendListVersions(ctx)
  local cmd = require("cmd")
  local json = require("json")

  local tool = ctx.tool
  local url = "https://www.nixhub.io/packages/" .. tool .. "?_data=routes%2F_nixhub.packages.%24pkg._index"

  local response = cmd.exec("curl -sL " .. url)
  local data = json.decode(response)

  local versions = {}
  for _, release in ipairs(data.releases or {}) do
    local version = release.version
    if version and version ~= "" then
      table.insert(versions, version)
    end
  end

  return { versions = versions }
end
