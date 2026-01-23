-- Neovim plugin detection, management, and installation
local shell = require("shell")
local logger = require("logger")
local file = require("file")

local M = {}

-- Plugin detection
function M.is_plugin(tool_name)
  if not tool_name then return false end
  return tool_name:match("^neovim%+install=vimPlugins%.") ~= nil
end

function M.extract_plugin_name(tool_or_flake)
  if not tool_or_flake then return nil end
  -- neovim+install=vimPlugins.nvim-treesitter -> nvim-treesitter
  -- neovim+install=vimPlugins.plenary-nvim -> plenary-nvim
  local name = tool_or_flake:match("vimPlugins%.([^@]+)")
  return name
end

function M.extract_flake_ref(tool_name)
  if not tool_name then return nil end
  -- neovim+install=vimPlugins.nvim-treesitter -> vimPlugins.nvim-treesitter
  local ref = tool_name:match("^neovim%+install=(.+)$")
  return ref
end

-- Directory management (XDG compliant)
function M.get_plugins_dir()
  local home = os.getenv("HOME")
  local xdg_data = os.getenv("XDG_DATA_HOME") or (home .. "/.local/share")
  return xdg_data .. "/nvim/site/pack/nix/start"
end

-- Install plugin via symlink to Neovim's pack directory
function M.install_plugin_from_store(nix_store_path, tool_name)
  logger.find("Detected Neovim plugin: " .. tool_name)

  -- Validate tool name first (before CI check, so tests can verify error handling)
  local plugin_name = M.extract_plugin_name(tool_name)
  if not plugin_name then
    error("Could not extract plugin name from: " .. tool_name)
  end

  -- In CI environments, skip actual Neovim plugin installation
  if os.getenv("CI") or os.getenv("GITHUB_ACTIONS") then
    logger.info("Skipping Neovim plugin installation in CI environment")
    logger.hint("Plugin available at: " .. nix_store_path)
    return "skipped_in_ci"
  end

  local plugins_dir = M.get_plugins_dir()
  local plugin_path = plugins_dir .. "/" .. plugin_name

  logger.debug("Plugin name: " .. plugin_name)
  logger.debug("Plugins directory: " .. plugins_dir)

  -- Create plugins directory if it doesn't exist
  shell.exec('mkdir -p "%s"', plugins_dir)

  -- Check if plugin is already installed and points to same path
  local ok, current_target = shell.try_exec('readlink "%s" 2>/dev/null', plugin_path)
  if ok and current_target and current_target:match(nix_store_path .. "$") then
    logger.info("Neovim plugin already installed: " .. plugin_name)
    return "already_installed"
  end

  -- Remove existing symlink/directory if it exists
  shell.try_exec('rm -rf "%s"', plugin_path)

  -- Create symlink to Nix store path
  file.symlink(nix_store_path, plugin_path)

  logger.done("Neovim plugin installed: " .. plugin_name)
  logger.info("Plugin location: " .. plugin_path)
  logger.hint("Plugin will auto-load on next Neovim start")

  return "installed"
end

return M
