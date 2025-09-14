-- JetBrains plugin detection, management, and installation
local shell = require("shell")
local logger = require("logger")
local tempdir = require("tempdir")
local cmd = require("cmd")
local file = require("file")
local platform = require("platform")

local M = {}

-- Plugin detection
function M.is_plugin(tool_name)
  if not tool_name then return false end
  return tool_name:match("^jetbrains%-plugins%.") ~= nil or tool_name:match("^jetbrains%+install=jetbrains%-plugins%.") ~= nil
end

function M.extract_plugin_info(tool_or_flake)
  if not tool_or_flake then return nil end

  -- Extract from patterns like: jetbrains-plugins.x86_64-linux.idea-ultimate.2024.3.com.intellij.plugins.watcher
  -- or: jetbrains+install=jetbrains-plugins.x86_64-linux.idea-ultimate.2024.3.com.intellij.plugins.watcher
  local pattern = tool_or_flake:match("jetbrains%-plugins%.(.+)")
      or tool_or_flake:match("^jetbrains%+install=jetbrains%-plugins%.(.+)")

  if not pattern then return nil end

  -- Parse the pattern: system.ide.version.plugin_id
  local parts = {}
  for part in pattern:gmatch("[^.]+") do
    table.insert(parts, part)
  end

  if #parts < 4 then return nil end

  -- Parse more carefully: system.ide.version.plugin_id
  -- Plugin IDs typically start with com., org., or are known patterns like jetbrains.
  local system = parts[1]  -- x86_64-linux
  local ide = parts[2]     -- idea-ultimate

  -- Find where plugin ID starts by looking for known plugin ID prefixes
  local plugin_start_idx = nil
  for i = 3, #parts do
    local part = parts[i]
    if part:match("^com$") or part:match("^org$") or part:match("^jetbrains$") or part:match("^intellij$") then
      plugin_start_idx = i
      break
    end
  end

  if not plugin_start_idx then
    -- If no known prefix found, look for patterns that don't look like version numbers
    for i = 3, #parts do
      local part = parts[i]
      -- If it's not a year-like number and not a single digit, it's probably the plugin ID
      if not part:match("^%d+$") and not part:match("^20%d%d$") then
        plugin_start_idx = i
        break
      end
    end
  end

  if not plugin_start_idx then
    -- Last resort: assume standard format system.ide.version.plugin_id
    plugin_start_idx = 4
  end

  -- Reconstruct version and plugin ID
  local version_parts = {}
  for i = 3, plugin_start_idx - 1 do
    table.insert(version_parts, parts[i])
  end
  local version = table.concat(version_parts, ".")

  local plugin_id_parts = {}
  for i = plugin_start_idx, #parts do
    table.insert(plugin_id_parts, parts[i])
  end
  local plugin_id = table.concat(plugin_id_parts, ".")

  return {
    system = system,
    ide = ide,
    version = version,
    plugin_id = plugin_id
  }
end


-- Directory management for different JetBrains IDEs
function M.get_plugins_dir(ide_name, version)
  local home = os.getenv("HOME")

  local ide_dirs = {
    ["idea-ultimate"] = "IntelliJIdea",
    ["idea-community"] = "IntelliJIdea",
    ["pycharm-professional"] = "PyCharm",
    ["pycharm-community"] = "PyCharmCE",
    ["webstorm"] = "WebStorm",
    ["phpstorm"] = "PhpStorm",
    ["rider"] = "Rider",
    ["clion"] = "CLion",
    ["goland"] = "GoLand",
    ["datagrip"] = "DataGrip",
    ["rubymine"] = "RubyMine",
    ["dataspell"] = "DataSpell"
  }

  local dir_name = ide_dirs[ide_name] or ide_name
  local os_type = platform.detect_os()

  if os_type == "macos" then
    -- macOS: ~/Library/Application Support/JetBrains/IntelliJIdea<version>/plugins
    return home .. "/Library/Application Support/JetBrains/" .. dir_name .. version .. "/plugins"
  else
    -- Linux: ~/.local/share/JetBrains/IntelliJIdea<version>/plugins
    return home .. "/.local/share/JetBrains/" .. dir_name .. version .. "/plugins"
  end
end

-- Plugin installation via extracted JAR/ZIP
function M.install_plugin(plugin_path, plugin_info)
  -- In CI environments, skip actual JetBrains plugin installation since it's experimental
  if os.getenv("CI") or os.getenv("GITHUB_ACTIONS") then
    logger.info("Skipping JetBrains plugin installation in CI environment")
    logger.info("JetBrains plugin functionality is experimental and not reliable in headless CI")
    return true, "skipped_in_ci"
  end

  local plugins_dir = M.get_plugins_dir(plugin_info.ide, plugin_info.version)

  -- Log OS detection for debugging
  logger.debug("Detected OS: " .. platform.detect_os())
  logger.debug("Plugin directory: " .. plugins_dir)

  -- Create plugins directory if it doesn't exist
  shell.exec('mkdir -p "%s"', plugins_dir)

  -- Check if we have JAR files to copy directly to plugins directory
  local jar_files_ok, jar_files = shell.try_exec('find "%s" -name "*.jar" -type f', plugin_path)
  if jar_files_ok and jar_files and jar_files:match("%S") then
    -- Copy JAR files directly to plugins directory
    local jar_list = {}
    for jar_file in jar_files:gmatch("[^\n]+") do
      local jar_name = jar_file:match("([^/]+)$")
      local target_path = plugins_dir .. "/" .. jar_name

      -- Check if JAR is already installed
      if shell.try_exec('test -f "%s"', target_path) then
        logger.info("JetBrains plugin JAR already installed: " .. jar_name)
        table.insert(jar_list, jar_name)
      else
        local copy_ok, copy_result = shell.try_exec('cp "%s" "%s"', jar_file, target_path)
        if copy_ok then
          logger.debug("Copied JAR: " .. jar_name)
          table.insert(jar_list, jar_name)
        else
          logger.fail("Failed to copy JAR: " .. jar_name)
          logger.debug("Copy error: " .. (copy_result or "unknown error"))
          return false, copy_result
        end
      end
    end

    if #jar_list > 0 then
      logger.done("JetBrains plugin installed: " .. plugin_info.plugin_id)
      logger.info("Plugin JARs: " .. table.concat(jar_list, ", "))
      logger.info("Plugin location: " .. plugins_dir)
      logger.info("Restart your JetBrains IDE to activate the plugin")
      return true, "installed"
    end
  end

  -- Fallback to directory-based installation
  local plugin_install_dir = plugins_dir .. "/" .. plugin_info.plugin_id

  -- Check if plugin is already installed
  if shell.try_exec('test -d "%s"', plugin_install_dir) then
    logger.info("JetBrains plugin already installed: " .. plugin_info.plugin_id)
    return true, "already_installed"
  end

  -- Create plugin directory
  shell.exec('mkdir -p "%s"', plugin_install_dir)

  -- Copy plugin files
  local copy_ok, copy_result = shell.try_exec('cp -r "%s"/* "%s/"', plugin_path, plugin_install_dir)

  if copy_ok then
    logger.done("JetBrains plugin installed: " .. plugin_info.plugin_id)
    logger.info("Plugin location: " .. plugin_install_dir)
    logger.info("Restart your JetBrains IDE to activate the plugin")
    return true, "installed"
  else
    logger.fail("JetBrains plugin installation failed")
    logger.debug("Copy error: " .. (copy_result or "unknown error"))
    -- Clean up failed installation
    shell.try_exec('rm -rf "%s"', plugin_install_dir)
    return false, copy_result
  end
end

-- Extract and install plugin from Nix store path
function M.install_from_nix_store(plugin_info, nix_store_path, tool_name)
  -- JetBrains plugins in Nix should be in the store path directly or in a lib subdirectory
  local plugin_path = nil

  -- Check different possible locations for the plugin
  local possible_paths = {
    nix_store_path,
    nix_store_path .. "/lib",
    nix_store_path .. "/share",
    nix_store_path .. "/plugins"
  }

  for _, path in ipairs(possible_paths) do
    if shell.try_exec('test -d "%s"', path) then
      -- Check if this directory contains plugin files (JAR files or plugin.xml)
      local has_jar = shell.try_exec('find "%s" -name "*.jar" | head -1', path)
      local has_plugin_xml = shell.try_exec('test -f "%s/META-INF/plugin.xml"', path)

      if has_jar or has_plugin_xml then
        plugin_path = path
        break
      end
    end
  end

  if not plugin_path then
    error("Could not find plugin files for " .. plugin_info.plugin_id .. " in " .. nix_store_path)
  end

  logger.debug("Plugin path: " .. plugin_path)

  -- Install the plugin
  local install_ok, install_status = M.install_plugin(plugin_path, plugin_info)

  return install_ok, install_status
end

-- Complete JetBrains plugin installation
function M.install_plugin_from_store(nix_store_path, tool_name)
  logger.find("Detected JetBrains plugin: " .. tool_name)

  -- Extract plugin information from tool name
  local plugin_info = M.extract_plugin_info(tool_name)
  if not plugin_info then
    error("Could not extract plugin information from: " .. tool_name)
  end

  logger.debug("Plugin info - IDE: " .. plugin_info.ide .. ", Version: " .. plugin_info.version .. ", Plugin ID: " .. plugin_info.plugin_id)

  -- Install plugin from Nix store
  local install_ok, install_status = M.install_from_nix_store(plugin_info, nix_store_path, tool_name)

  if not install_ok then
    error("JetBrains plugin installation failed for " .. tool_name)
  end

  -- Handle CI skip case
  if install_status == "skipped_in_ci" then
    logger.pack("JetBrains plugin prepared (installation skipped in CI): " .. plugin_info.plugin_id)
  else
    logger.pack("JetBrains plugin installed: " .. plugin_info.plugin_id)
  end

  return plugin_info.plugin_id
end

return M