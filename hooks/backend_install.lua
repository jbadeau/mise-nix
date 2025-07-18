function PLUGIN:BackendInstall(ctx)
  local cmd = require("cmd")
  local json = require("json")

  local tool = ctx.tool
  local version_str = ctx.version
  local install_path = ctx.install_path

  -- re-fetch metadata
  local url = "https://www.nixhub.io/packages/" .. tool .. "?_data=routes%2F_nixhub.packages.%24pkg._index"
  local response = cmd.exec("curl -sL " .. url)
  local data = json.decode(response)

  local commit = nil
  local attr = nil

  for _, release in ipairs(data.releases or {}) do
    if release.version == version_str then
      local platform = release.platforms and release.platforms[1]
      if platform then
        commit = platform.commit_hash
        attr = platform.attribute_path
        break
      end
    end
  end

  if not commit or not attr then
    error("Could not find commit/attr for " .. tool .. "@" .. version_str)
  end

  local ref = string.format("github:NixOS/nixpkgs/%s#%s", commit, attr)
  local cmdline = string.format("nix build --no-link --print-out-paths " ..
    "--extra-experimental-features nix-command " ..
    "--extra-experimental-features flakes '%s'", ref)

  local result = cmd.exec(cmdline)
  local store_path = result:match("^([^\n]+)")

  if not store_path then
    error("Failed to parse nix build output")
  end

  -- Replace install_path with symlink to store path
  cmd.exec(string.format('rm -rf "%s"', install_path))
  cmd.exec(string.format('ln -sfn "%s" "%s"', store_path, install_path))

  return {}
end
