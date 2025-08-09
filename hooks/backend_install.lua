local cmd = require("cmd")
local json = require("json")
local helper = require("helper")

local function install_to_vscode(chosen_path, tool)
  local vscode_ext_dir = os.getenv("HOME") .. "/.vscode/extensions"
  cmd.exec("mkdir -p " .. vscode_ext_dir)
  
  -- Extract extension ID from the package name
  local ext_id = tool:match("vscode%-extensions%.(.+)") or tool:match("^vscode%+install=vscode%-extensions%.(.+)") or tool
  local target_dir = vscode_ext_dir .. "/" .. ext_id
  
  -- Remove existing and create symlink
  cmd.exec(string.format('rm -rf "%s"', target_dir))
  cmd.exec(string.format('ln -sfn "%s" "%s"', chosen_path, target_dir))
  
  print("📦 Installed VSCode extension: " .. ext_id)
  return true
end

local function resolve_version_alias(requested_version, compatible)
  if requested_version == "latest" or requested_version == "" then
    return compatible[#compatible]
  elseif requested_version == "stable" then
    -- Find latest stable version
    local versions = {}
    for _, release in ipairs(compatible) do
      table.insert(versions, release.version)
    end
    table.sort(versions, helper.semver_less_than)
    local stable_version = helper.find_latest_stable(versions)

    for _, release in ipairs(compatible) do
      if release.version == stable_version then
        return release
      end
    end
    return compatible[#compatible] -- fallback
  else
    -- Exact version match
    for _, release in ipairs(compatible) do
      if release.version == requested_version then
        return release
      end
    end
    return nil
  end
end

local function install_from_nixhub(tool, requested_version, install_path)
  local current_os = helper.normalize_os(RUNTIME.osType)
  local current_arch = RUNTIME.archType:lower()

  local success, data, response = helper.fetch_tool_metadata_cached(tool, 3600)
  helper.validate_tool_metadata(success, data, tool, response)

  local compatible = helper.filter_compatible_versions(data.releases, current_os, current_arch)
  if #compatible == 0 then
    error("No compatible versions found for " .. tool .. " on " .. current_os .. " (" .. current_arch .. ")")
  end

  table.sort(compatible, function(a, b)
    return helper.semver_less_than(a.version, b.version)
  end)

  local target_release = resolve_version_alias(requested_version, compatible)
  if not target_release then
    error("Requested version not found or not compatible: " .. requested_version)
  end

  local platform = target_release.platforms and target_release.platforms[1]
  if not platform then
    error("No platform build found for version " .. target_release.version)
  end

  local nixpkgs_url = helper.get_nixpkgs_repo_url()
  local repo_ref = nixpkgs_url:gsub("https://github.com/", "github:")
  local ref = string.format("%s/%s#%s", repo_ref, platform.commit_hash, platform.attribute_path)
  local cmdline = string.format("nix build --no-link --print-out-paths '%s'", ref)

  print("🔨 Building " .. tool .. "@" .. target_release.version .. "...")
  local result = cmd.exec(cmdline)
  local outputs = {}
  for path in result:gmatch("[^\n]+") do
    table.insert(outputs, path)
  end

  if #outputs == 0 then
    error("No outputs returned by nix build")
  end

  local chosen_path, has_bin = helper.choose_store_path_with_bin(outputs)
  if not has_bin then
    print("⚠️  No binaries found. This package may be a library.")
    print("ℹ️  Falling back to the first available output for linking or use in build environments.")
  end

  helper.verify_build(chosen_path, tool)

  -- Check if it's a VSCode extension
  if tool:match("^vscode%-extensions%.") then
    print("🔍 Detected VSCode extension: " .. tool)
    install_to_vscode(chosen_path, tool)
  else
    -- Standard mise tool installation
    print("🔧 Installing as standard tool: " .. tool)
    cmd.exec(string.format('rm -rf "%s"', install_path))
    cmd.exec(string.format('ln -sfn "%s" "%s"', chosen_path, install_path))
  end

  print("✅ Successfully installed " .. tool .. "@" .. target_release.version)
  return target_release.version
end

local function install_from_flake(flake_ref, version, install_path)
  local outputs, built_ref = helper.build_flake(flake_ref, version)

  local chosen_path, has_bin = helper.choose_store_path_with_bin(outputs)
  
  -- Check if it's a VSCode extension first to provide appropriate messaging
  local is_vscode_ext = flake_ref:match("vscode%-extensions%.") or flake_ref:match("^vscode%+install=vscode%-extensions%.")
  
  if not has_bin then
    if is_vscode_ext then
      print("📦 VSCode extension package (no CLI binaries expected)")
    else
      print("⚠️  No binaries found. This package may be a library.")
      print("ℹ️  Falling back to the first available output for linking or use in build environments.")
    end
  end

  helper.verify_build(chosen_path, flake_ref)

  -- Check if it's a VSCode extension
  if is_vscode_ext then
    print("🔍 Detected VSCode extension flake: " .. flake_ref)
    install_to_vscode(chosen_path, flake_ref)
  else
    -- Standard mise tool installation
    print("🔧 Installing as standard flake tool: " .. flake_ref)
    cmd.exec(string.format('rm -rf "%s"', install_path))
    cmd.exec(string.format('ln -sfn "%s" "%s"', chosen_path, install_path))

    -- WORKAROUND: mise expects a directory named after the nix store hash for direct flake references
    -- Extract the nix store hash from the chosen_path and create an additional symlink
    local nix_hash = chosen_path:match("/nix/store/([^/]+)")
    if nix_hash then
      local install_dir = install_path:match("^(.+)/[^/]+$") -- Get parent directory
      local hash_path = install_dir .. "/" .. nix_hash
      cmd.exec(string.format('rm -rf "%s"', hash_path))
      cmd.exec(string.format('ln -sfn "%s" "%s"', chosen_path, hash_path))
    end
  end

  print("✅ Successfully installed " .. built_ref)
  
  -- Return both the flake_ref and chosen_path for VSCode extensions
  if flake_ref:match("vscode%-extensions%.") or flake_ref:match("^vscode%+install=vscode%-extensions%.") then
    return flake_ref, chosen_path
  else
    return flake_ref
  end
end

function PLUGIN:BackendInstall(ctx)
  local tool = ctx.tool
  local requested_version = ctx.version
  local install_path = ctx.install_path

  
  helper.check_nix_available()

  local result_version
  local nix_store_path = nil

  -- Check if it's a VSCode extension - treat as flake reference
  if tool:match("^vscode%-extensions%.") then
    local flake_ref = "nixpkgs#" .. tool
    result_version, nix_store_path = install_from_flake(flake_ref, requested_version, install_path)
  elseif tool:match("^vscode%+install=vscode%-extensions%.") then
    -- Handle vscode+install=vscode-extensions.publisher.extension syntax
    result_version, nix_store_path = install_from_flake(tool, requested_version, install_path)
  -- Check if either the tool or version is a flake reference
  elseif helper.is_flake_reference(tool) then
    result_version = install_from_flake(tool, requested_version, install_path)
  elseif helper.is_flake_reference(requested_version) then
    result_version = install_from_flake(requested_version, "", install_path)
  else
    result_version = install_from_nixhub(tool, requested_version, install_path)
  end

  -- Post-install: If it's a VSCode extension, install via marketplace with Nix version pinning
  if (tool:match("^vscode%-extensions%.") or tool:match("^vscode%+install=vscode%-extensions%.")) and nix_store_path then
    local ext_id = tool:match("vscode%-extensions%.(.+)") or tool:match("^vscode%+install=vscode%-extensions%.(.+)")
    
    -- The actual extension is in share/vscode/extensions/{ext_id}/ within the nix store
    local actual_ext_path = nix_store_path .. "/share/vscode/extensions/" .. ext_id
    
    -- Create VSIX file for backup/offline use (stored in mise install directory)
    local vsix_filename = tool:gsub("%.", "-") .. ".vsix"
    local vsix_path = install_path .. "/" .. vsix_filename
    
    -- Create VSIX by zipping the extension directory contents
    local zip_cmd = string.format('cd "%s" && zip -r "%s" * -x "*.DS_Store"', actual_ext_path, vsix_path)
    local zip_success, zip_output = pcall(function()
      return cmd.exec(zip_cmd)
    end)
    
    if not zip_success then
      print("⚠️  VSIX backup creation failed (continuing anyway)")
    end
    
    -- Install via marketplace (most reliable method)
    local install_cmd = string.format('code --install-extension "%s"', ext_id)
    
    local install_success, install_output = pcall(function()
      return cmd.exec(install_cmd)
    end)
    
    if install_success then
      print("✅ VSCode extension installed successfully")
      if install_output and install_output ~= "" then
        -- Print success message from VSCode
        local lines = {}
        for line in install_output:gmatch("[^\n]+") do
          if line:match("successfully installed") or line:match("Extension.*installed") then
            table.insert(lines, "   " .. line)
          end
        end
        if #lines > 0 then
          for _, line in ipairs(lines) do
            print(line)
          end
        end
      end
      print("💡 Extension version managed by Nix (" .. result_version .. "), installed via marketplace")
    else
      print("❌ VSCode marketplace installation failed")
      if zip_success then
        print("💡 VSIX backup available at: " .. vsix_path)
      end
    end
  end

  return { version = result_version }

end