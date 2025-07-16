function PLUGIN:BackendExecEnv(ctx)
  return {
    env_vars = {
      { key = "PATH", value = ctx.install_path .. "/bin" }
    }
  }
end
