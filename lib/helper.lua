local M = {}

-- These modules are provided by the mise runtime
-- For testing, mock implementations are available in lib/cmd.lua and lib/json.lua
local cmd = require("cmd")
local json = require("json")

function M.normalize_os(os)
  os = os:lower()
  if os == "darwin" then return "macos"
  elseif os == "linux" then return "linux"
  elseif os == "windows" then return "windows"
  else return os
  end
end

function M.is_compatible(summary, os, arch)
  summary = (summary or ""):lower()
  if not summary:find(os, 1, true) then return false end
  if summary:find("intel only", 1, true) and arch == "arm64" then return false end
  if summary:find("arm only", 1, true) and arch == "amd64" then return false end
  return true
end

function M.is_valid_version(version)
  if type(version) ~= "string" or version == "" then return false end
  return version:match("^[%w%.%-]+$") ~= nil
end

function M.get_nixhub_base_url()
  return os.getenv("MISE_NIX_NIXHUB_BASE_URL") or "https://www.nixhub.io"
end

function M.get_nixpkgs_repo_url()
  return os.getenv("MISE_NIX_NIXPKGS_REPO_URL") or "https://github.com/NixOS/nixpkgs"
end

function M.get_cache_path(tool)
  local cache_dir = os.getenv("HOME") .. "/.cache/mise-nix"
  cmd.exec("mkdir -p " .. cache_dir)
  return cache_dir .. "/" .. tool .. ".json"
end

-- Security functions for local flake handling

function M.allow_local_flakes()
  return os.getenv("MISE_NIX_ALLOW_LOCAL_FLAKES") == "true"
end

function M.is_safe_local_path(path)
  -- Only allow paths within current working directory and block dangerous paths
  if not path or type(path) ~= "string" then return false end
  
  -- Block obviously dangerous paths
  local dangerous_patterns = {
    "^/etc/",
    "^/usr/",
    "^/bin/",
    "^/sbin/",
    "^/boot/",
    "^/root/",
    "^/home/[^/]+/%.ssh/",
    "^/home/[^/]+/%.gnupg/",
    "/%.%./"  -- path traversal attempts
  }
  
  for _, pattern in ipairs(dangerous_patterns) do
    if path:match(pattern) then return false end
  end
  
  -- For relative paths, ensure they don't escape the current directory
  if path:match("^%.%.") then
    -- Count directory traversals
    local up_count = 0
    for _ in path:gmatch("%.%./") do
      up_count = up_count + 1
    end
    -- Don't allow going up more than 2 levels to prevent deep traversal
    if up_count > 2 then return false end
  end
  
  -- For absolute paths, check if they're within a safe directory
  if path:match("^/") then
    local cwd = cmd.exec("pwd 2>/dev/null || echo ''"):gsub("\n", "")
    if cwd == "" then return false end
    
    -- Try to resolve the real path
    local realpath = cmd.exec("realpath '" .. path .. "' 2>/dev/null || echo INVALID"):gsub("\n", "")
    if realpath == "INVALID" then return false end
    
    -- Only allow paths within current working directory or its subdirectories
    return realpath:sub(1, #cwd) == cwd
  end
  
  return true
end

function M.validate_local_flake_security(flake_ref)
  local parsed = M.parse_flake_reference(flake_ref)
  local is_local = parsed.url:match("^%.") or parsed.url:match("^/") or 
                   parsed.url:match("^path:") or parsed.url:match("^file:")
  
  if not is_local then return true end
  
  -- Check if local flakes are allowed
  if not M.allow_local_flakes() then
    error("Local flakes are disabled for security. Set MISE_NIX_ALLOW_LOCAL_FLAKES=true to enable.")
  end
  
  -- Extract path from URL
  local path = parsed.url
  if path:match("^path:") then
    path = path:gsub("^path:", "")
  elseif path:match("^file:") then
    path = path:gsub("^file:", "")
  end
  
  -- Validate the path is safe
  if not M.is_safe_local_path(path) then
    error("Local flake path is not safe: " .. path .. ". Path must be within current working directory and not access sensitive system directories.")
  end
  
  return true
end

-- Convert custom git prefixes to standard nix flake URLs
function M.convert_custom_git_prefix(version)
  if not version or type(version) ~= "string" then return version end
  
  -- New syntax with + separator: ssh+host/repo.git -> git+ssh://host/repo.git
  -- This avoids conflicts with # used for flake attributes
  
  -- SSH URLs: ssh+... -> git+ssh://...
  if version:match("^ssh%+") then
    local path = version:gsub("^ssh%+", "")
    -- Ensure proper URL format for git+ssh
    if not path:match("^[%w%-_%.]+@") then
      -- If it doesn't start with user@, add git@ prefix
      path = "git@" .. path
    end
    return "git+ssh://" .. path
  end
  
  -- HTTPS URLs: https+... -> git+https://...
  if version:match("^https%+") then
    local path = version:gsub("^https%+", "")
    return "git+https://" .. path
  end
  
  -- GitHub shorthand: gh+user/repo -> github:user/repo
  if version:match("^gh%+[%w%-_%.]+/[%w%-_%.]+") then
    local path = version:gsub("^gh%+", "")
    return "github:" .. path
  end
  
  -- GitLab shorthand: gl+group/project -> gitlab:group/project  
  if version:match("^gl%+[%w%-_%.]+/[%w%-_%.]+") then
    local path = version:gsub("^gl%+", "")
    return "gitlab:" .. path
  end
  
  -- Legacy patterns (keep for backward compatibility)
  
  -- GitHub shorthand: gh-user/repo -> github:user/repo
  if version:match("^gh%-[%w%-_%.]+/[%w%-_%.]+") then
    local path = version:gsub("^gh%-", "")
    return "github:" .. path
  end
  
  -- GitLab shorthand: gl-group/project -> gitlab:group/project  
  if version:match("^gl%-[%w%-_%.]+/[%w%-_%.]+") then
    local path = version:gsub("^gl%-", "")
    return "gitlab:" .. path
  end
  
  -- SSH URLs: ssh-git@... -> git+ssh://git@...
  if version:match("^ssh%-") then
    local path = version:gsub("^ssh%-", "")
    return "git+ssh://" .. path
  end
  
  -- HTTPS URLs: https-... -> git+https://...
  if version:match("^https%-") then
    local path = version:gsub("^https%-", "")
    return "git+https://" .. path
  end
  
  -- Custom enterprise instances via environment variables
  local github_enterprise = os.getenv("MISE_NIX_GITHUB_ENTERPRISE_URL")
  local gitlab_instance = os.getenv("MISE_NIX_GITLAB_ENTERPRISE_URL")
  
  -- GitHub Enterprise shorthand: ghe+user/repo
  if github_enterprise and version:match("^ghe%+") then
    local path = version:gsub("^ghe%+", "")
    return "git+https://" .. github_enterprise .. "/" .. path
  end
  
  -- GitLab instance shorthand: gli+group/project  
  if gitlab_instance and version:match("^gli%+") then
    local path = version:gsub("^gli%+", "")
    return "git+https://" .. gitlab_instance .. "/" .. path
  end
  
  -- Legacy enterprise patterns
  if github_enterprise and version:match("^ghe%-") then
    local path = version:gsub("^ghe%-", "")
    return "git+https://" .. github_enterprise .. "/" .. path
  end
  
  if gitlab_instance and version:match("^gli%-") then
    local path = version:gsub("^gli%-", "")
    return "git+https://" .. gitlab_instance .. "/" .. path
  end
  
  return version
end

-- New function to detect if a tool name is a flake reference
function M.is_flake_reference(tool)
  if not tool or type(tool) ~= "string" then return false end

  -- Check for flake reference patterns (including custom prefixes)
  local patterns = {
    "^github:",           -- github:owner/repo#package
    "^gitlab:",           -- gitlab:owner/repo#package
    "^git%+https://",     -- git+https://...#package
    "^git%+ssh://",       -- git+ssh://...#package
    "^ssh%+",             -- ssh+host/repo.git#package (new syntax)
    "^https%+",           -- https+host/repo.git#package (new syntax)
    "^gh%+",              -- gh+owner/repo#package (new GitHub shorthand)
    "^gl%+",              -- gl+group/project#package (new GitLab shorthand)
    "^ghe%+",             -- ghe+owner/repo#package (new GitHub Enterprise)
    "^gli%+",             -- gli+group/project#package (new GitLab instance)
    "^gh%-",              -- gh-owner/repo#package (legacy GitHub shorthand)
    "^gl%-",              -- gl-group/project#package (legacy GitLab shorthand)
    "^ssh%-",             -- ssh-git@...#package (legacy SSH URLs)
    "^https%-",           -- https-...#package (legacy HTTPS URLs)
    "^ghe%-",             -- ghe-owner/repo#package (legacy GitHub Enterprise)
    "^gli%-",             -- gli-group/project#package (legacy GitLab instance)
    "^%.%./",             -- ../relative/path#package
    "^%.?/",              -- ./relative/path#package (added for current dir relative paths)
    "^/",                 -- /absolute/path#package
    "^[%w%-_%.]+/[%w%-_%.]+#",  -- owner/repo#package (GitHub shorthand)
    "^nixpkgs#",          -- nixpkgs#hello (common shorthand)
    "^path:",             -- path:/some/path#package
    "^file:",             -- file:/some/path#package
  }

  for _, pattern in ipairs(patterns) do
    if tool:match(pattern) then return true end
  end

  -- Check if it looks like a path that might omit the leading ./ but still be a flake
  if tool:match("^[%w%-_%.]+#") then -- e.g., "my-flake#package" assuming current dir
      -- This is ambiguous, could be a regular package name with a hash in it
      -- For now, we'll keep it as false unless more context is available
      -- The safest bet is to require a more explicit path or URL prefix.
  end

  return false
end

-- Parse flake reference into components
function M.parse_flake_reference(flake_ref)
  local flake_url, attribute = flake_ref:match("^(.-)#(.+)$")

  -- If no attribute is explicitly provided, assume 'default'
  if not attribute and flake_ref:find("#") then
      error("Invalid flake reference format. Expected 'flake_url#attribute', but attribute is empty after '#'. Got: " .. flake_ref)
  elseif not attribute then -- No '#' found, so attribute is implicitly 'default'
      flake_url = flake_ref
      attribute = "default"
  end

  -- Convert custom git prefixes to standard nix flake URLs
  flake_url = M.convert_custom_git_prefix(flake_url)

  -- Normalize GitHub shorthand (owner/repo -> github:owner/repo)
  -- But exclude local paths that start with ./ or ../
  if flake_url:match("^[%w%-_%.]+/[%w%-_%.]+$") and not flake_url:match("^%.") then
    flake_url = "github:" .. flake_url
  end

  return {
    url = flake_url,
    attribute = attribute,
    full_ref = flake_url .. "#" .. attribute
  }
end

-- Get available versions for a flake (mock implementation for now)
function M.get_flake_versions(flake_ref)
  -- NOTE: This is a mock implementation.
  -- For flakes, enumerating historical versions like with traditional package registries is complex
  -- and generally requires inspecting the flake's git history or specific commands.
  -- For now, we return 'latest' or 'local' as logical representations.
  local parsed = M.parse_flake_reference(flake_ref)

  -- Try to get commit info if it's a git-based flake
  if parsed.url:match("github:") or parsed.url:match("gitlab:") or parsed.url:match("git%+") then
    return {"latest"}  -- For now, just return "latest"
  elseif parsed.url:match("^%.") or parsed.url:match("^/") or parsed.url:match("^path:") or parsed.url:match("^file:") then
    -- Local flakes - return current state
    return {"local"}
  else
    return {"latest"} -- Default for other recognized flake types
  end
end

-- Build a flake reference
function M.build_flake(flake_ref, version)
  -- Validate that it's actually a flake reference
  if not M.is_flake_reference(flake_ref) then
    error("Invalid flake reference")
  end
  
  local parsed = M.parse_flake_reference(flake_ref)
  
  -- Security validation and warnings for local flakes
  local is_local = parsed.url:match("^%.") or parsed.url:match("^/") or 
                   parsed.url:match("^path:") or parsed.url:match("^file:")
  
  if is_local then
    print("⚠️  WARNING: Using local flake - ensure you trust the source: " .. parsed.url)
    print("   Local flakes can execute arbitrary code during evaluation and build.")
    M.validate_local_flake_security(flake_ref)
  end

  local build_ref = parsed.full_ref

  -- If version is specified and not "latest"/"local"/"", try to append it as a revision
  if version and version ~= "latest" and version ~= "local" and version ~= "" then
    -- For git-based flakes, we can specify a revision
    if parsed.url:match("github:") or parsed.url:match("gitlab:") then
      -- Remove any existing revision (if present) and add the new one
      local base_url = parsed.url:gsub("/[a-fA-F0-9]+$", ""):gsub("/v?%d+%.%d+%.%d+.*$", "") -- Remove existing hash/tag
      build_ref = base_url .. "/" .. version .. "#" .. parsed.attribute
    elseif parsed.url:match("git%+") then
      -- For git+ URLs, we need to add ?ref= or ?rev= parameter
      local separator = parsed.url:find("?") and "&" or "?"
      -- Remove existing ref/rev if present before adding the new one
      local cleaned_url = parsed.url:gsub("([%?&])(ref|rev)=[^&#]+", ""):gsub("[?&]$", "")
      build_ref = cleaned_url .. separator .. "rev=" .. version .. "#" .. parsed.attribute
    end
  end

  -- Build with security-focused options
  local sandbox_flag = ""
  local extra_sandbox_flag = ""
  
  -- Enable sandbox for better security isolation
  if os.getenv("MISE_NIX_ENABLE_SANDBOX") ~= "false" then
    sandbox_flag = "--sandbox"
  end
  
  -- Add extra security flags for untrusted sources
  if is_local or os.getenv("MISE_NIX_EXTRA_SECURITY") == "true" then
    extra_sandbox_flag = "--restrict-eval"
  end
  
  local cmdline = string.format("nix build --no-link --print-out-paths %s %s '%s'", 
                                sandbox_flag, extra_sandbox_flag, build_ref)

  print("🔨 Building flake " .. build_ref .. "...")
  local result = cmd.exec(cmdline)
  local outputs = {}
  for path in result:gmatch("[^\n]+") do
    table.insert(outputs, path)
  end

  if #outputs == 0 then
    error("No outputs returned by nix build for flake: " .. build_ref)
  end

  return outputs, build_ref
end

function M.fetch_tool_metadata(tool)

  local url = M.get_nixhub_base_url() .. "/packages/" .. tool .. "?_data=routes%2F_nixhub.packages.%24pkg._index"

  -- Add timeout and better error handling
  local response = cmd.exec("curl -sL --max-time 10 --retry 2 \"" .. url .. "\"")

  if response:match("^curl:") or response == "" then
    return false, nil, "Failed to fetch package metadata from nixhub.io"
  end

  local success, data = pcall(json.decode, response)
  return success, data, response
end

function M.fetch_tool_metadata_cached(tool, max_age_seconds)
  local cache_file = M.get_cache_path(tool)

  -- Check if cache exists and is fresh
  local stat = cmd.exec("stat -c %Y " .. cache_file .. " 2>/dev/null || echo 0")
  local cache_time = tonumber(stat) or 0

  if os.time() - cache_time < (max_age_seconds or 3600) then
    local cached = cmd.exec("cat " .. cache_file .. " 2>/dev/null")
    if cached and cached ~= "" then
      local success, data = pcall(json.decode, cached)
      if success then return success, data, cached end
    end
  end

  -- Fetch fresh data and cache it
  local success, data, response = M.fetch_tool_metadata(tool)
  if success then
    cmd.exec("echo '" .. response:gsub("'", "'\"'\"'") .. "' > " .. cache_file)
  end
  return success, data, response
end

function M.validate_tool_metadata(success, data, tool, response)
  if not success or not data or not data.releases then
    error("Tool not found or missing releases: " .. tool .. "\nResponse:\n" .. (response or ""))
  end
end

function M.parse_semver(version)
  local major, minor, patch, pre = version:match("^(%d+)%.(%d+)%.(%d+)[%-%.]?(.*)$")
  return {
    major = tonumber(major) or 0,
    minor = tonumber(minor) or 0,
    patch = tonumber(patch) or 0,
    pre = pre or ""
  }
end

function M.semver_less_than(a, b)
  local va = M.parse_semver(a)
  local vb = M.parse_semver(b)

  if va.major ~= vb.major then return va.major < vb.major end
  if va.minor ~= vb.minor then return va.minor < vb.minor end
  if va.patch ~= vb.patch then return va.patch < vb.patch end

  if va.pre == "" and vb.pre ~= "" then return false end
  if va.pre ~= "" and vb.pre == "" then return true end
  return va.pre < vb.pre
end

function M.filter_compatible_versions(releases, os, arch)
  local filtered = {}
  for _, release in ipairs(releases) do
    if M.is_compatible(release.platforms_summary, os, arch) then
      table.insert(filtered, release)
    end
  end
  return filtered
end

function M.find_latest_stable(versions)
  for i = #versions, 1, -1 do
    local parsed = M.parse_semver(versions[i])
    if parsed.pre == "" then
      return versions[i]
    end
  end
  return versions[#versions] -- fallback to actual latest
end

function M.choose_store_path_with_bin(outputs)
  local candidates = {}

  for _, path in ipairs(outputs) do
    local bin_path = path .. "/bin"
    local has_bin = cmd.exec("test -d '" .. bin_path .. "' && echo yes || echo no"):match("yes")
    local bin_count = 0

    if has_bin then
      bin_count = tonumber(cmd.exec("ls -1 '" .. bin_path .. "' 2>/dev/null | wc -l")) or 0
    end

    table.insert(candidates, {path = path, has_bin = has_bin, bin_count = bin_count})
  end

  -- Prefer output with most binaries, then any with binaries, then first output
  table.sort(candidates, function(a, b)
    if a.has_bin and not b.has_bin then return true end
    if not a.has_bin and b.has_bin then return false end
    return a.bin_count > b.bin_count
  end)

  if #candidates == 0 then
      error("No valid output paths found from nix build.")
  end

  return candidates[1].path, candidates[1].has_bin
end

function M.check_nix_available()
  local result = cmd.exec("which nix 2>/dev/null || echo MISSING")
  if result:match("MISSING") then
    error("Nix is not installed or not in PATH. Please install Nix first.")
  end
end

function M.verify_build(chosen_path, tool)
  -- Check if the path actually exists and is accessible
  local exists = cmd.exec("test -e '" .. chosen_path .. "' && echo yes || echo no"):match("yes")
  if not exists then
    error("Built package path does not exist: " .. chosen_path)
  end

  -- Optional: verify expected binaries exist
  local bin_path = chosen_path .. "/bin"
  local has_bin_dir = cmd.exec("test -d '" .. bin_path .. "' && echo yes || echo no"):match("yes")
  if has_bin_dir then
    local binaries = cmd.exec("ls -1 '" .. bin_path .. "' 2>/dev/null")
    if binaries and binaries ~= "" then
      print("Installed binaries: " .. binaries:gsub("\n", ", "))
    else
      print("Installed package contains a /bin directory but it is empty.")
    end
  end
end

return M