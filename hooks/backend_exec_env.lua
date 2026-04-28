function PLUGIN:BackendExecEnv(ctx)
  local env = require("nix_env")

  local ok, env_vars = pcall(env.for_context, ctx)
  if ok and env_vars and #env_vars > 0 then
    return { env_vars = env_vars }
  end

  -- Ultimate fallback: bare PATH to install_path/bin
  return {
    env_vars = {
      { key = "PATH", value = ctx.install_path .. "/bin" }
    }
  }
end
