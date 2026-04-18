function PLUGIN:BackendListVersions(ctx)
  local flake = require("flake")
  local platform = require("platform")
  local nixhub = require("nixhub")
  local version = require("version")
  local vscode = require("vscode")
  local jetbrains = require("jetbrains")
  local neovim = require("neovim")
  local shell = require("shell")
  local file = require("file")
  local tool = ctx.tool

  if not tool or tool == "" then
    error("Tool name cannot be empty")
  end

  -- Invalidate exec_env cache for local flake references when the working
  -- directory changes, so BackendExecEnv re-runs and can update the install
  -- symlink to point to the correct nix store path.
  local cache_dir = os.getenv("MISE_CACHE_DIR") or (os.getenv("HOME") .. "/.cache/mise")
  local current_dir = os.getenv("PWD") or ""
  local tool_cache_dir = cache_dir .. "/nix-" .. tool
  local breadcrumb = tool_cache_dir .. "/last_cwd"

  local last_dir = ""
  if file.exists(breadcrumb) then
    last_dir = file.read(breadcrumb) or ""
  end

  if last_dir ~= current_dir then
    -- Clear exec_env cache for all nix tools so BackendExecEnv re-runs.
    -- All nix-* dirs must be cleared because this hook may only fire for
    -- one tool while other tools also need cache invalidation.
    shell.try_exec('find "%s" -path "*/nix-*/exec_env_*" -delete 2>/dev/null', cache_dir)
    shell.try_exec('mkdir -p "%s"', tool_cache_dir)
    local wf = io.open(breadcrumb, "w")
    if wf then
      wf:write(current_dir)
      wf:close()
    end
  end

  -- If this is a JetBrains plugin, return a single "latest" version
  -- since plugins are managed by the nix-jetbrains-plugins flake
  if jetbrains.is_plugin(tool) then
    return { versions = { "latest" } }
  end

  -- If this is a Neovim plugin, return a single "latest" version
  -- since plugins are from nixpkgs vimPlugins
  if neovim.is_plugin(tool) then
    return { versions = { "latest" } }
  end

  -- If this is a VSCode extension that uses the install format, also return "latest"
  if vscode.is_extension(tool) and tool:match("^vscode%+install=") then
    return { versions = { "latest" } }
  end

  -- If this is a flake reference, we return available versions for that flake
  if flake.is_reference(tool) then
    local versions = flake.get_versions(tool)
    return { versions = versions }
  end

  -- If the requested version is a flake reference, return the version itself
  -- since flakes don't have traditional version lists

  -- mise doesn't provide ctx.version when calling BackendListVersions. (https://mise.jdx.dev/backend-plugin-development.html#backendlistversions-context)

  -- local requested_version = ctx.version
  -- if requested_version and flake.is_reference(requested_version) then
  --   return { versions = { requested_version } }
  -- end

  -- Use traditional nixhub.io workflow for regular package names
  local current_os = platform.normalize_os(RUNTIME.osType)
  local current_arch = RUNTIME.archType:lower()

  local success, data, response = nixhub.fetch_metadata(tool)

  -- If package not found in nixhub, return empty list
  -- This allows flake reference versions to work (e.g., nix:mytool@gitlab+group/repo#default)
  -- The actual validation happens during install when we have access to the version
  if not success or not data or not data.releases then
    return { versions = {"latest"} }
  end

  local versions = {}
  for _, release in ipairs(data.releases) do
    local release_version = release.version
    if version.is_valid(release_version)
        and version.is_compatible(release.platforms_summary, current_os, current_arch) then
      table.insert(versions, release_version)
    end
  end

  -- For ls-remote, return empty list if no compatible versions found
  if #versions == 0 then
    return { versions = {} }
  end

  -- Reverse so latest versions appear at the bottom of the list
  local reversed = {}
  for i = #versions, 1, -1 do
    table.insert(reversed, versions[i])
  end

  return { versions = reversed }
end
