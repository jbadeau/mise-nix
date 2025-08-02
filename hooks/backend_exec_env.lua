function PLUGIN:BackendExecEnv(ctx)
  local cmd = require("cmd")
  
  -- Resolve symlinks to get the actual nix store path
  local real_path = cmd.exec("readlink -f '" .. ctx.install_path .. "' 2>/dev/null || echo '" .. ctx.install_path .. "'"):gsub("\n", "")
  
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
        { key = "PATH", value = ctx.install_path .. "/bin" }
      }
    }
  end
end
