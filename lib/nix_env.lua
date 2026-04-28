-- Nix environment subsystem
-- Caches nix print-dev-env at install time, reads cache at exec time
local shell = require("shell")
local platform = require("platform")
local logger = require("logger")

local M = {}

M.CACHE_SUFFIX = ".nix-env.json"

-- Runtime env var hints: packages where nix print-dev-env doesn't expose the
-- needed variable (it only gives the *build* env, not the *consumer* env).
-- These are derived from the actual nix store path at install time.
-- Pattern matches against the nix store path basename.
M.STORE_PATH_HINTS = {
  { pattern = "%-openjdk%-",   var = "JAVA_HOME" },
  { pattern = "%-jdk%-",       var = "JAVA_HOME" },
  { pattern = "%-go%-",        var = "GOROOT" },
  { pattern = "%-python3%-",   var = "PYTHONHOME" },
}

-- Get the configured env mode: auto | dev-env | path-only
function M.get_env_mode()
  local mode = os.getenv("MISE_NIX_ENV_MODE") or "auto"
  if mode ~= "auto" and mode ~= "dev-env" and mode ~= "path-only" then
    logger.warn("Unknown MISE_NIX_ENV_MODE=" .. mode .. ", falling back to auto")
    return "auto"
  end
  return mode
end

-- Variables from print-dev-env that are build-time only (not useful at runtime)
-- These are excluded from the cached env
M.BUILD_TIME_VARS = {
  -- Nix internals
  NIX_BUILD_CORES = true, NIX_BUILD_TOP = true, NIX_STORE = true,
  NIX_LOG_FD = true, NIX_ENFORCE_PURITY = true, NIX_ENFORCE_NO_NATIVE = true,
  NIX_BINTOOLS = true, NIX_CC = true, NIX_CFLAGS_COMPILE = true,
  NIX_LDFLAGS = true, NIX_HARDENING_ENABLE = true,
  NIX_DONT_SET_RPATH = true, NIX_DONT_SET_RPATH_FOR_BUILD = true,
  NIX_NO_SELF_RPATH = true, NIX_IGNORE_LD_THROUGH_GCC = true,
  NIX_BINTOOLS_WRAPPER_TARGET_HOST_arm64_apple_darwin = true,
  NIX_CC_WRAPPER_TARGET_HOST_arm64_apple_darwin = true,
  NIX_APPLE_SDK_VERSION = true,
  -- Compiler/linker
  CC = true, CXX = true, AR = true, AS = true, LD = true,
  NM = true, RANLIB = true, STRIP = true, SIZE = true, STRINGS = true,
  OBJCOPY = true, OBJDUMP = true,
  -- Build flags
  cmakeFlags = true, mesonFlags = true, configureFlags = true,
  -- Build metadata
  buildInputs = true, nativeBuildInputs = true, propagatedBuildInputs = true,
  propagatedNativeBuildInputs = true, patches = true, src = true,
  builder = true, stdenv = true, system = true, outputs = true, out = true,
  name = true, pname = true, version = true, strictDeps = true,
  depsBuildBuild = true, depsBuildBuildPropagated = true,
  depsBuildTarget = true, depsBuildTargetPropagated = true,
  depsHostHost = true, depsHostHostPropagated = true,
  depsTargetTarget = true, depsTargetTargetPropagated = true,
  doCheck = true, doInstallCheck = true, dontAddDisableDepTrack = true,
  postInstallCheck = true,
  -- Shell/temp
  SHELL = true, CONFIG_SHELL = true, shell = true,
  TEMP = true, TEMPDIR = true, TMP = true, TMPDIR = true,
  HOME = true, OLDPWD = true, TERM = true, TZ = true,
  SOURCE_DATE_EPOCH = true, ZERO_AR_DATE = true,
  -- Darwin-specific build
  SDKROOT = true, DEVELOPER_DIR = true, MACOSX_DEPLOYMENT_TARGET = true,
  LD_DYLD_PATH = true,
  -- Nix shell marker
  IN_NIX_SHELL = true,
  -- Sandbox
  __darwinAllowLocalNetworking = true, __impureHostDeps = true,
  __propagatedImpureHostDeps = true, __propagatedSandboxProfile = true,
  __sandboxProfile = true, __structuredAttrs = true,
}

-- Check if a variable from print-dev-env is useful at runtime
function M.is_runtime_var(key)
  if M.BUILD_TIME_VARS[key] then return false end
  -- Exclude any key starting with __ (nix internal)
  if key:match("^__") then return false end
  -- Exclude NIX_BINTOOLS/CC wrapper vars for any architecture
  if key:match("^NIX_.*WRAPPER_TARGET_HOST") then return false end
  return true
end

-- Parse the JSON output from `nix print-dev-env --json`
-- Returns a list of { key = "...", value = "..." } for exported variables
function M.parse_print_dev_env_json(json_string)
  if not json_string or json_string == "" then
    return nil, "empty JSON input"
  end

  local json = require("json")
  local ok, data = pcall(json.decode, json_string)
  if not ok or not data then
    return nil, "failed to parse JSON"
  end

  local variables = data.variables
  if not variables or type(variables) ~= "table" then
    return nil, "no variables in print-dev-env output"
  end

  local env_vars = {}
  for key, entry in pairs(variables) do
    if type(entry) == "table" and entry.type == "exported" and entry.value then
      if M.is_runtime_var(key) then
        table.insert(env_vars, { key = key, value = entry.value })
      end
    end
  end

  if #env_vars == 0 then
    return nil, "no exported variables found"
  end

  -- Sort for deterministic output
  table.sort(env_vars, function(a, b) return a.key < b.key end)

  return env_vars, nil
end

-- Run `nix print-dev-env --json` and cache the result to install_path
-- Called during `mise install`, not during `mise exec`
function M.cache_dev_env(flake_ref, install_path)
  if not flake_ref or flake_ref == "" then
    return nil, "no flake reference provided"
  end
  if not install_path or install_path == "" then
    return nil, "no install path provided"
  end

  local env_prefix = platform.get_env_prefix()
  local impure_flag = platform.get_impure_flag()
  local dev_env_cmd = string.format(
    "%snix print-dev-env %s--json '%s' 2>/dev/null",
    env_prefix, impure_flag, flake_ref
  )

  logger.info("Caching environment variables...")
  logger.debug("Running: " .. dev_env_cmd)
  local ok, result = shell.try_exec(dev_env_cmd)
  if not ok or not result or result == "" then
    logger.debug("nix print-dev-env failed for " .. flake_ref .. ", skipping env cache")
    return nil, "nix print-dev-env failed"
  end

  -- Validate the JSON parses correctly before caching
  local env_vars, err = M.parse_print_dev_env_json(result)
  if not env_vars then
    logger.debug("print-dev-env output not usable: " .. (err or "unknown"))
    return nil, err
  end

  -- Write raw JSON to cache file as sibling of install_path
  -- (install_path is a symlink to read-only nix store, so we write next to it)
  local cache_path = install_path .. M.CACHE_SUFFIX
  local fh, write_err = io.open(cache_path, "w")
  if not fh then
    logger.debug("Failed to write env cache to " .. cache_path .. ": " .. (write_err or "unknown"))
    return nil, "failed to write cache"
  end
  fh:write(result)
  fh:close()

  logger.debug("Cached env vars to " .. cache_path)
  return env_vars, nil
end

-- Read cached env vars from sibling of install_path (fast, no nix evaluation)
function M.load_cached_env(install_path)
  if not install_path or install_path == "" then
    return nil, "no install path"
  end

  local cmd = require("cmd")

  -- Cache is a sibling file next to the install_path symlink
  local cache_path = install_path .. M.CACHE_SUFFIX
  local exists = cmd.exec("test -f '" .. cache_path .. "' && echo yes || echo no"):match("yes")
  if exists then
    local read_ok, content = shell.try_exec('cat "%s"', cache_path)
    if read_ok and content and content ~= "" then
      return M.parse_print_dev_env_json(content)
    end
  end

  return nil, "no cached env found"
end

-- Build fallback PATH-only env vars from an install path.
-- Also adds MANPATH, INFOPATH, XDG_DATA_DIRS when their dirs exist.
function M.fallback_path_env(install_path)
  if not install_path or install_path == "" then
    return {}
  end

  local cmd = require("cmd")

  -- Resolve symlinks to get the actual nix store path
  local real_path = cmd.exec("readlink -f '" .. install_path .. "' 2>/dev/null || echo '" .. install_path .. "'"):gsub("\n", "")

  local env_vars = {}

  -- PATH
  local bin_path = real_path .. "/bin"
  local has_bin = cmd.exec("test -d '" .. bin_path .. "' && echo yes || echo no"):match("yes")
  if has_bin then
    table.insert(env_vars, { key = "PATH", value = bin_path })
  else
    table.insert(env_vars, { key = "PATH", value = install_path .. "/bin" })
  end

  -- MANPATH
  local man_paths = M.collect_man_paths(install_path, real_path)
  if #man_paths > 0 then
    table.insert(env_vars, { key = "MANPATH", value = table.concat(man_paths, ":") .. ":" })
  end

  -- INFOPATH
  local info_path = real_path .. "/share/info"
  local has_info = cmd.exec("test -d '" .. info_path .. "' && echo yes || echo no"):match("yes")
  if has_info then
    table.insert(env_vars, { key = "INFOPATH", value = info_path })
  end

  -- XDG_DATA_DIRS
  local share_path = real_path .. "/share"
  local has_share = cmd.exec("test -d '" .. share_path .. "' && echo yes || echo no"):match("yes")
  if has_share then
    table.insert(env_vars, { key = "XDG_DATA_DIRS", value = share_path })
  end

  return env_vars
end

-- Collect man directories for all active Nix tools.
-- This avoids later tools overwriting earlier MANPATH entries during shell activation.
function M.collect_man_paths(install_path, real_path)
  local cmd = require("cmd")
  local json = require("json")
  local seen = {}
  local man_paths = {}

  local function add_man_path(man_path)
    if seen[man_path] then
      return
    end
    local has_man = cmd.exec("test -d '" .. man_path .. "' && echo yes || echo no"):match("yes")
    if has_man then
      seen[man_path] = true
      table.insert(man_paths, man_path)
    end
  end

  local ok, tool_json = pcall(cmd.exec, "mise ls --current --installed --json 2>/dev/null")
  if ok and tool_json and tool_json ~= "" then
    local decoded_ok, tools = pcall(json.decode, tool_json)
    if decoded_ok and type(tools) == "table" then
      for tool_name, versions in pairs(tools) do
        if type(tool_name) == "string" and tool_name:match("^nix:") and type(versions) == "table" then
          for _, entry in ipairs(versions) do
            if type(entry) == "table" and entry.active and entry.install_path then
              add_man_path(entry.install_path .. "/share/man")
            end
          end
        end
      end
    end
  end

  add_man_path(install_path .. "/share/man")
  add_man_path(real_path .. "/share/man")

  return man_paths
end

-- Derive env vars from the nix store path using hints
-- e.g. if store path contains "-openjdk-", set JAVA_HOME to the store path
function M.store_path_env(install_path)
  if not install_path or install_path == "" then
    return {}
  end

  local cmd = require("cmd")
  local real_path = cmd.exec("readlink -f '" .. install_path .. "' 2>/dev/null || echo '" .. install_path .. "'"):gsub("\n", "")

  local env_vars = {}
  for _, hint in ipairs(M.STORE_PATH_HINTS) do
    if real_path:match(hint.pattern) then
      table.insert(env_vars, { key = hint.var, value = real_path })
    end
  end

  return env_vars
end

-- Main entry point for exec time: resolve env vars for a given context
-- Always uses fallback PATH/MANPATH/etc from installed binaries,
-- then merges in extra vars from cached print-dev-env (JAVA_HOME, GOROOT, etc.)
function M.for_context(ctx)
  local mode = M.get_env_mode()

  -- Always start with PATH-based env from the actual installed binaries
  local base_env = M.fallback_path_env(ctx.install_path)

  -- Add store-path-derived hints (JAVA_HOME, GOROOT, etc.)
  local hints = M.store_path_env(ctx.install_path)
  for _, v in ipairs(hints) do
    table.insert(base_env, v)
  end

  if mode == "path-only" then
    return base_env
  end

  -- Try reading cached env (written at install time)
  local cached_vars, err = M.load_cached_env(ctx.install_path)
  if cached_vars then
    logger.debug("Merging cached print-dev-env variables")
    -- Build a set of keys already in base_env
    local base_keys = {}
    for _, v in ipairs(base_env) do
      base_keys[v.key] = true
    end
    -- Add cached vars that aren't already covered by base env
    for _, v in ipairs(cached_vars) do
      if not base_keys[v.key] then
        table.insert(base_env, v)
      end
    end
    return base_env
  end

  if mode == "dev-env" then
    error("MISE_NIX_ENV_MODE=dev-env but no cached env found: " .. (err or "unknown error") .. ". Reinstall the package to generate the cache.")
  end

  logger.debug("No cached env (" .. (err or "unknown") .. "), using PATH-only")
  return base_env
end

return M
