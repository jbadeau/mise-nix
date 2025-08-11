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
  local ok, output = shell.try_exec('code --install-extension "%s" 2>&1', vsix_path)
  
  -- VSCode might return non-zero exit code even on success, so check output content
  if output and (output:match("successfully installed") or output:match("Extension.*installed")) then
    logger.done("VSCode extension installed via VSIX")
    -- Print the success message
    for line in output:gmatch("[^\n]+") do
      if line:match("successfully installed") or line:match("Extension.*installed") then
        print("   " .. line)
      end
    end
    return true, "installed"
  elseif output and output:match("is already installed") then
    logger.info("VSCode extension already installed")
    return true, "already_installed"
  else
    -- If we get here, there was likely a real failure
    logger.fail("VSCode VSIX installation failed")
    if output and output ~= "" then
      print("   Error: " .. output)
    end
    return false, output
  end
end

-- Create required VSIX manifest files
function M.create_vsix_manifest(temp_dir, ext_id, ext_path)
  -- Read package.json to extract extension metadata
  local package_json_path = ext_path .. "/package.json"
  local package_json_content = ""
  local ok, result = shell.try_exec('cat "%s"', package_json_path)
  if ok then
    package_json_content = result
  end
  local package_data = {}
  
  if package_json_content then
    -- Simple JSON parsing for the fields we need
    package_data.name = package_json_content:match('"name"%s*:%s*"([^"]+)"') or ext_id
    package_data.displayName = package_json_content:match('"displayName"%s*:%s*"([^"]+)"') or package_data.name
    package_data.description = package_json_content:match('"description"%s*:%s*"([^"]+)"') or ""
    package_data.version = package_json_content:match('"version"%s*:%s*"([^"]+)"') or "1.0.0"
    package_data.publisher = package_json_content:match('"publisher"%s*:%s*"([^"]+)"') or "unknown"
    package_data.categories = package_json_content:match('"categories"%s*:%s*%[([^%]]+)%]') or ""
    package_data.keywords = package_json_content:match('"keywords"%s*:%s*%[([^%]]+)%]') or ""
    package_data.icon = package_json_content:match('"icon"%s*:%s*"([^"]+)"') or ""
    package_data.license = package_json_content:match('"license"%s*:%s*"([^"]+)"') or ""
    
    -- Parse engine version
    local engines = package_json_content:match('"engines"%s*:%s*{([^}]+)}')
    if engines then
      package_data.engine = engines:match('"vscode"%s*:%s*"([^"]+)"') or "^1.74.0"
    else
      package_data.engine = "^1.74.0"
    end
  else
    package_data.name = ext_id
    package_data.displayName = ext_id
    package_data.description = ""
    package_data.version = "1.0.0"
    package_data.publisher = "unknown"
    package_data.categories = ""
    package_data.keywords = ""
    package_data.icon = ""
    package_data.license = ""
    package_data.engine = "^1.74.0"
  end
  
  -- Create [Content_Types].xml with common file types for VSCode extensions
  local content_types = [[<?xml version="1.0" encoding="utf-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension=".json" ContentType="application/json"/><Default Extension=".vsixmanifest" ContentType="text/xml"/><Default Extension=".md" ContentType="text/markdown"/><Default Extension=".js" ContentType="application/javascript"/><Default Extension=".ts" ContentType="application/typescript"/><Default Extension=".html" ContentType="text/html"/><Default Extension=".css" ContentType="text/css"/><Default Extension=".scss" ContentType="text/css"/><Default Extension=".less" ContentType="text/css"/><Default Extension=".xml" ContentType="text/xml"/><Default Extension=".yaml" ContentType="text/yaml"/><Default Extension=".yml" ContentType="text/yaml"/><Default Extension=".txt" ContentType="text/plain"/><Default Extension=".log" ContentType="text/plain"/><Default Extension=".py" ContentType="text/plain"/><Default Extension=".go" ContentType="text/plain"/><Default Extension=".java" ContentType="text/plain"/><Default Extension=".c" ContentType="text/plain"/><Default Extension=".cpp" ContentType="text/plain"/><Default Extension=".h" ContentType="text/plain"/><Default Extension=".hpp" ContentType="text/plain"/><Default Extension=".rs" ContentType="text/plain"/><Default Extension=".php" ContentType="text/plain"/><Default Extension=".rb" ContentType="text/plain"/><Default Extension=".sh" ContentType="text/plain"/><Default Extension=".png" ContentType="image/png"/><Default Extension=".jpg" ContentType="image/jpeg"/><Default Extension=".jpeg" ContentType="image/jpeg"/><Default Extension=".gif" ContentType="image/gif"/><Default Extension=".svg" ContentType="image/svg+xml"/><Default Extension=".ico" ContentType="image/x-icon"/><Default Extension=".ttf" ContentType="font/ttf"/><Default Extension=".woff" ContentType="font/woff"/><Default Extension=".woff2" ContentType="font/woff2"/><Default Extension=".eot" ContentType="application/vnd.ms-fontobject"/></Types>]]
  
  shell.exec('cat > "%s/[Content_Types].xml" << \'EOF\'\n%sEOF', temp_dir, content_types)
  
  -- Determine icon and license paths
  local icon_path = ""
  local license_path = ""
  
  if package_data.icon ~= "" then
    icon_path = "extension/" .. package_data.icon
  else
    -- Look for common icon files
    local common_icons = {"icon.png", "images/icon.png", "media/icon.png", "assets/icon.png"}
    for _, icon_file in ipairs(common_icons) do
      local ok, _ = shell.try_exec('test -f "%s"', ext_path .. "/" .. icon_file)
      if ok then
        icon_path = "extension/" .. icon_file
        break
      end
    end
  end
  
  -- Look for license files
  local common_licenses = {"LICENSE", "LICENSE.txt", "LICENSE.md", "license", "license.txt", "license.md"}
  for _, license_file in ipairs(common_licenses) do
    local ok, _ = shell.try_exec('test -f "%s"', ext_path .. "/" .. license_file)
    if ok then
      license_path = "extension/" .. license_file
      break
    end
  end

  -- Clean up categories and keywords
  local categories = package_data.categories:gsub('"', ''):gsub('%s*,%s*', ',')
  local tags = package_data.keywords:gsub('"', ''):gsub('%s*,%s*', ',')
  
  -- Create extension.vsixmanifest
  local vsix_manifest = string.format([[<?xml version="1.0" encoding="utf-8"?>
	<PackageManifest Version="2.0.0" xmlns="http://schemas.microsoft.com/developer/vsx-schema/2011" xmlns:d="http://schemas.microsoft.com/developer/vsx-schema-design/2011">
		<Metadata>
			<Identity Language="en-US" Id="%s" Version="%s" Publisher="%s" />
			<DisplayName>%s</DisplayName>
			<Description xml:space="preserve">%s</Description>
			<Tags>%s</Tags>
			<Categories>%s</Categories>
			<GalleryFlags>Public</GalleryFlags>
			
			<Properties>
				<Property Id="Microsoft.VisualStudio.Code.Engine" Value="%s" />
				<Property Id="Microsoft.VisualStudio.Code.ExtensionDependencies" Value="" />
				<Property Id="Microsoft.VisualStudio.Code.ExtensionPack" Value="" />
				<Property Id="Microsoft.VisualStudio.Code.ExtensionKind" Value="workspace" />
				<Property Id="Microsoft.VisualStudio.Code.LocalizedLanguages" Value="" />
				
				<Property Id="Microsoft.VisualStudio.Services.Links.Source" Value="" />
				<Property Id="Microsoft.VisualStudio.Services.Links.Getstarted" Value="" />
				<Property Id="Microsoft.VisualStudio.Services.Links.GitHub" Value="" />
				<Property Id="Microsoft.VisualStudio.Services.Links.Support" Value="" />
				<Property Id="Microsoft.VisualStudio.Services.Links.Learn" Value="" />
				<Property Id="Microsoft.VisualStudio.Services.Branding.Color" Value="#F2F2F2" />
				<Property Id="Microsoft.VisualStudio.Services.Branding.Theme" Value="light" />
				<Property Id="Microsoft.VisualStudio.Services.GitHubFlavoredMarkdown" Value="true" />
				<Property Id="Microsoft.VisualStudio.Services.Content.Pricing" Value="Free"/>

				
				
			</Properties>%s%s
		</Metadata>
		<Installation>
			<InstallationTarget Id="Microsoft.VisualStudio.Code"/>
		</Installation>
		<Dependencies/>
		<Assets>
			<Asset Type="Microsoft.VisualStudio.Code.Manifest" Path="extension/package.json" Addressable="true" />%s%s%s
		</Assets>
	</PackageManifest>]], 
    package_data.name, package_data.version, package_data.publisher, package_data.displayName, package_data.description,
    tags, categories, package_data.engine,
    license_path ~= "" and string.format('\n\t\t\t<License>%s</License>', license_path) or "",
    icon_path ~= "" and string.format('\n\t\t\t<Icon>%s</Icon>', icon_path) or "",
    (function() local ok, _ = shell.try_exec('test -f "%s"', ext_path .. "/README.md"); return ok end)() and '\n\t\t\t<Asset Type="Microsoft.VisualStudio.Services.Content.Details" Path="extension/README.md" Addressable="true" />' or "",
    (function() local ok, _ = shell.try_exec('test -f "%s"', ext_path .. "/CHANGELOG.md"); return ok end)() and '\n\t\t\t<Asset Type="Microsoft.VisualStudio.Services.Content.Changelog" Path="extension/CHANGELOG.md" Addressable="true" />' or "",
    license_path ~= "" and string.format('\n\t\t\t<Asset Type="Microsoft.VisualStudio.Services.Content.License" Path="%s" Addressable="true" />', license_path) or ""
  )
  
  -- Add icon asset if found
  if icon_path ~= "" then
    vsix_manifest = vsix_manifest:gsub("</Assets>", string.format('\t\t\t<Asset Type="Microsoft.VisualStudio.Services.Icons.Default" Path="%s" Addressable="true" />\n\t\t</Assets>', icon_path))
  end
  
  shell.exec('cat > "%s/extension.vsixmanifest" << \'EOF\'\n%sEOF', temp_dir, vsix_manifest)
end

-- VSIX file creation and installation
function M.create_and_install_vsix(ext_id, nix_store_path, install_dir, tool_name)
  -- VSCode extensions in Nix are located at share/vscode/extensions/{ext_id}
  local ext_path = nix_store_path .. "/share/vscode/extensions/" .. ext_id
  local vsix_name = (tool_name or ext_id):gsub("%.", "-") .. ".vsix"
  local vsix_path = install_dir .. "/" .. vsix_name
  
  -- Create VSIX file with proper structure
  local zip_ok = pcall(function()
    -- Create temp directory for proper VSIX structure
    local temp_dir = install_dir .. "/vsix_temp"
    shell.exec('mkdir -p "%s/extension"', temp_dir)
    shell.exec('cp -r "%s"/. "%s/extension/"', ext_path, temp_dir)
    -- Fix permissions on copied files so they can be deleted
    shell.exec('chmod -R u+w "%s"', temp_dir)
    
    -- Create required VSIX manifest files
    M.create_vsix_manifest(temp_dir, ext_id, ext_path)
    
    shell.exec('cd "%s" && zip -r "%s" . -x "*.DS_Store"', temp_dir, vsix_path)
    shell.exec('rm -rf "%s"', temp_dir)
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