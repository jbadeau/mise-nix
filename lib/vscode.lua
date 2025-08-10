-- VSCode extension detection, management, and installation
local shell = require("shell")
local logger = require("logger")

local M = {}

-- Extension detection
function M.is_extension(tool_name)
  if not tool_name then return false end
  return tool_name:match("^vscode%-extensions%.") ~= nil or tool_name:match("^vscode%+install=vscode%-extensions%.") ~= nil
end

function M.extract_extension_id(tool_or_flake)
  if not tool_or_flake then return nil end
  return tool_or_flake:match("vscode%-extensions%.(.+)")
      or tool_or_flake:match("^vscode%+install=vscode%-extensions%.(.+)")
end

-- Directory management
function M.get_extensions_dir()
  return os.getenv("HOME") .. "/.vscode/extensions"
end

-- Extension symlink installation (for file system access)
function M.install_extension_symlink(nix_store_path, tool_name)
  local ext_id = M.extract_extension_id(tool_name)
  if not ext_id then
    error("Could not extract extension ID from: " .. tool_name)
  end
  
  local ext_dir = M.get_extensions_dir()
  local target_path = ext_dir .. "/" .. ext_id
  
  shell.exec('mkdir -p "%s"', ext_dir)
  shell.symlink_force(nix_store_path, target_path)
  
  logger.pack("Installed VSCode extension: " .. ext_id)
  return ext_id
end

-- VSIX installation (for VSCode recognition)
function M.install_via_vsix(vsix_path)
  local ok, output = shell.try_exec('code --install-extension "%s"', vsix_path)
  
  if not ok then
    logger.fail("VSCode VSIX installation failed")
    return false, output
  end
  
  if output and output:match("is already installed") then
    logger.info("VSCode extension already installed")
    return true, "already_installed"
  else
    logger.done("VSCode extension installed via VSIX")
    if output and output ~= "" then
      -- Print relevant success messages from VSCode
      for line in output:gmatch("[^\n]+") do
        if line:match("successfully installed") or line:match("Extension.*installed") then
          print("   " .. line)
        end
      end
    end
    return true, "installed"
  end
end

-- VSIX file creation and installation
function M.create_and_install_vsix(ext_id, nix_store_path, install_dir, tool_name)
  -- VSCode extensions in Nix are located at share/vscode/extensions/{ext_id}
  local ext_path = nix_store_path .. "/share/vscode/extensions/" .. ext_id
  local vsix_name = (tool_name or ext_id):gsub("%.", "-") .. ".vsix"
  local vsix_path = install_dir .. "/" .. vsix_name
  
  -- Create VSIX file
  local zip_ok = pcall(function()
    shell.exec('cd "%s" && zip -r "%s" * -x "*.DS_Store"', ext_path, vsix_path)
  end)
  
  if not zip_ok then
    logger.fail("VSIX creation failed")
    return false, nil
  end
  
  logger.done("Created VSIX: " .. vsix_path)
  
  -- Install the VSIX file
  local install_ok, install_status = M.install_via_vsix(vsix_path)
  
  return install_ok, vsix_path, install_status
end

-- Complete VSCode extension installation (both symlink and VSIX)
function M.install_extension(nix_store_path, install_path, tool_name)
  logger.find("Detected VSCode extension: " .. tool_name)
  
  -- Install extension files via symlink (for file access)
  local ext_id = M.install_extension_symlink(nix_store_path, tool_name)
  
  -- Create VSIX and install it in VSCode
  local vsix_ok, vsix_path, install_status = M.create_and_install_vsix(ext_id, nix_store_path, install_path, tool_name)
  
  if not vsix_ok then
    logger.warn("VSIX installation failed - extension files still available via symlink")
  end
  
  return ext_id
end

return M