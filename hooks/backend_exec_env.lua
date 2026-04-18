function PLUGIN:BackendExecEnv(ctx)
  local cmd = require("cmd")
  local shell = require("shell")
  local flake = require("flake")

  local tool = ctx.tool
  local version = ctx.version
  local install_path = ctx.install_path

  -- Determine the effective flake reference
  local effective_flake_ref = tool
  if not flake.is_reference(tool) and flake.is_reference(version) then
    effective_flake_ref = version
  end

  -- For local flake references (./# or ../#), build from the current working
  -- directory and update the install symlink if the nix store path differs.
  if flake.is_local(effective_flake_ref) then
    local build_ok, store_path = shell.try_exec(
      "nix build '%s' --no-link --print-out-paths 2>/dev/null",
      effective_flake_ref
    )

    if build_ok and store_path then
      store_path = store_path:gsub("%s+$", "")
      local current_target = cmd.exec("readlink '" .. install_path .. "' 2>/dev/null"):gsub("%s+$", "")

      if current_target ~= store_path then
        shell.symlink_force(store_path, install_path)
      end
    end
  end

  -- Resolve symlinks to get the actual nix store path
  local real_path = cmd.exec("readlink -f '" .. install_path .. "' 2>/dev/null || echo '" .. install_path .. "'"):gsub("\n", "")

  -- Check if the resolved path has a bin directory
  local bin_path = real_path .. "/bin"
  local has_bin = cmd.exec("test -d '" .. bin_path .. "' && echo yes || echo no"):match("yes")

  if has_bin then
    return {
      env_vars = {
        { key = "PATH", value = bin_path }
      }
    }
  else
    -- Fallback to the original logic if no bin directory found
    return {
      env_vars = {
        { key = "PATH", value = install_path .. "/bin" }
      }
    }
  end
end
