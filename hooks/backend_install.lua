function PLUGIN:BackendInstall(ctx)
  local cmd = require("cmd")
  local utils = require("utils")

  local tool = ctx.tool
  local requested_version = ctx.version
  local install_path = ctx.install_path

  local current_os = utils.normalize_os(RUNTIME.osType)
  local current_arch = RUNTIME.archType:lower()

  local success, data, response = utils.fetch_tool_metadata(tool)
  utils.validate_tool_metadata(success, data, tool, response)

  local compatible = {}
  for _, release in ipairs(data.releases) do
    if utils.is_compatible(release.platforms_summary, current_os, current_arch) then
      table.insert(compatible, release)
    end
  end

  if #compatible == 0 then
    error("No compatible versions found for " .. tool .. " on " .. current_os .. " (" .. current_arch .. ")")
  end

  table.sort(compatible, function(a, b)
    return utils.semver_less_than(a.version, b.version)
  end)

  local target_release = nil
  if requested_version and requested_version ~= "" and requested_version ~= "latest" then
    for _, r in ipairs(compatible) do
      if r.version == requested_version then
        target_release = r
        break
      end
    end
    if not target_release then
      error("Requested version not found or not compatible: " .. requested_version)
    end
  else
    target_release = compatible[#compatible] -- latest
  end

  local platform = target_release.platforms and target_release.platforms[1]
  if not platform then
    error("No platform build found for version " .. target_release.version)
  end

  local repo_url = utils.get_nixpkgs_repo_url()
  local ref = string.format("github:%s/%s#%s", repo_url:gsub("https://github.com/", ""), platform.commit_hash, platform.attribute_path)

  local build_flags = "--extra-experimental-features nix-command --extra-experimental-features flakes"

  if os.getenv("MISE_NIX_ONLY_CACHED") == "1" then
    build_flags = build_flags .. " --max-jobs 0"
  end

  local cmdline = string.format("nix build --no-link --print-out-paths %s '%s'", build_flags, ref)

  local result = cmd.exec(cmdline)
  local store_path = result:match("^([^\n]+)")

  if not store_path then
    error("Failed to parse nix build output")
  end

  cmd.exec(string.format('rm -rf "%s"', install_path))
  cmd.exec(string.format('ln -sfn "%s" "%s"', store_path, install_path))

  return {}
end
