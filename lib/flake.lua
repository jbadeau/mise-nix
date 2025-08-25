-- Nix flake reference handling and manipulation
local shell = require("shell")
local logger = require("logger")

local M = {}

-- Detect if a tool name is a flake reference
function M.is_reference(tool)
  if not tool or type(tool) ~= "string" then return false end

  -- Check for flake reference patterns (including custom prefixes)
  local patterns = {
    -- Standard Nix flake patterns
    "^github:",           -- github:owner/repo#package (standard Nix GitHub flake)
    "^gitlab:",           -- gitlab:group/project#package (standard Nix GitLab flake)
    "^git%+https://",     -- git+https://...#package (standard Nix git flake)
    "^git%+ssh://",       -- git+ssh://...#package (standard Nix git flake)
    "^path:",             -- path:/some/path#package (path URI)
    "^file:",             -- file:/some/path#package (file URI)
    "nixpkgs#",           -- nixpkgs#hello (nixpkgs shorthand)
    
    -- Local path patterns (must contain # to be flake reference)
    "^%./.*#",            -- ./my-flake#package (relative path)
    "^%../.*#",           -- ../my-flake#package (relative path)
    "^/.*#",              -- /absolute/path/flake#tool (absolute path with # for flake)
    
    -- Owner/repo shorthand (e.g., nixos/nixpkgs#hello)
    "^[%w%-_%.]+/[%w%-_%.]+#", -- owner/repo#package shorthand
    
    -- Custom patterns with plus separator
    "^github%+",          -- github+owner/repo#package (GitHub shorthand)
    "^gitlab%+",          -- gitlab+group/project#package (GitLab shorthand)  
    "^vscode%+install=vscode%-extensions%.", -- vscode+install=vscode-extensions.publisher.extension (VSCode extension install)
    "^ssh%+",             -- ssh+host/repo.git#package (for tool@source only)
    "^https%+",           -- https+host/repo.git#package (for tool@source only)
    "^ghe%+",             -- ghe+user/repo#package (GitHub Enterprise)
    "^gli%+",             -- gli+group/project#package (GitLab Enterprise)
    "^vscode%-extensions%.", -- vscode-extensions.publisher.extension (normal package)
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

-- Convert custom git prefixes to standard nix flake URLs
function M.convert_custom_git_prefix(version)
  if not version or type(version) ~= "string" then return version end
  
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
  
  -- GitHub shorthand: github+user/repo -> github:user/repo
  if version:match("^github%+[%w%-_%.]+/[%w%-_%.]+") then
    local path = version:gsub("^github%+", "")
    return "github:" .. path
  end
  
  -- GitLab shorthand: gitlab+group/project -> gitlab:group/project  
  if version:match("^gitlab%+[%w%-_%.]+/[%w%-_%.]+") then
    local path = version:gsub("^gitlab%+", "")
    return "gitlab:" .. path
  end
  
  -- GitHub Enterprise: ghe+user/repo -> git+https://github.company.com/user/repo
  -- Only transform if environment variable is set
  if version:match("^ghe%+[%w%-_%.]+/[%w%-_%.]+") then
    local github_enterprise_url = os.getenv("MISE_NIX_GITHUB_ENTERPRISE_URL")
    if github_enterprise_url then
      local path = version:gsub("^ghe%+", "")
      return "git+https://" .. github_enterprise_url:gsub("https://", "") .. "/" .. path
    end
  end
  
  -- GitLab Enterprise: gli+group/project -> git+https://gitlab.company.com/group/project
  -- Only transform if environment variable is set
  if version:match("^gli%+[%w%-_%.]+/[%w%-_%.]+") then
    local gitlab_enterprise_url = os.getenv("MISE_NIX_GITLAB_ENTERPRISE_URL")
    if gitlab_enterprise_url then
      local path = version:gsub("^gli%+", "")
      return "git+https://" .. gitlab_enterprise_url:gsub("https://", "") .. "/" .. path
    end
  end
  
  return version
end

-- Parse Git hosting shortcuts with enhanced ref support
function M.parse_git_ref_syntax(flake_url)
  if not flake_url or type(flake_url) ~= "string" then return flake_url end
  
  -- Handle github:owner/repo/branch syntax
  local github_match = flake_url:match("^github:([%w%-_%.]+/[%w%-_%.]+)/([%w%-_%.]+)$")
  if github_match then
    local repo, branch = github_match:match("^(.+)/([^/]+)$")
    if repo and branch then
      return "github:" .. repo .. "/" .. branch
    end
  end
  
  -- Handle complex query parameters: ?ref=X&dir=Y, ?rev=X&dir=Y, etc.
  -- This preserves all Git ref parameters that Nix supports
  if flake_url:match("%?") then
    -- Just return as-is - Nix will handle complex query parameters
    return flake_url
  end
  
  -- Handle gitlab:group/project/branch syntax  
  local gitlab_match = flake_url:match("^gitlab:([%w%-_%.]+/[%w%-_%.]+)/([%w%-_%.]+)$")
  if gitlab_match then
    local repo, branch = gitlab_match:match("^(.+)/([^/]+)$")
    if repo and branch then
      return "gitlab:" .. repo .. "/" .. branch
    end
  end
  
  return flake_url
end

-- Parse flake reference into components with enhanced ref support
function M.parse_reference(flake_ref)
  -- Handle VSCode install syntax (vscode+install=vscode-extensions.publisher.extension)
  if flake_ref:match("^vscode%+install=vscode%-extensions%.") then
    local ext_package = flake_ref:gsub("^vscode%+install=", "")
    return {
      url = "nixpkgs",
      attribute = ext_package,
      full_ref = "nixpkgs#" .. ext_package,
      install_mode = "vscode"
    }
  end
  
  -- Handle VSCode extensions directly (vscode-extensions.publisher.extension)
  if flake_ref:match("^vscode%-extensions%.") then
    return {
      url = "nixpkgs",
      attribute = flake_ref,
      full_ref = "nixpkgs#" .. flake_ref
    }
  end
  
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

  -- Parse GitHub/GitLab shortcuts with branch/tag/ref support
  -- Handle formats like: github:owner/repo/branch, github:owner/repo?ref=v1.0.0, etc.
  flake_url = M.parse_git_ref_syntax(flake_url)

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
function M.get_versions(flake_ref)
  -- NOTE: This is a mock implementation.
  -- For flakes, enumerating historical versions like with traditional package registries is complex
  -- and generally requires inspecting the flake's git history or specific commands.
  -- For now, we return 'latest' or 'local' as logical representations.
  local parsed = M.parse_reference(flake_ref)

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

-- Build a flake reference with security validation
function M.build(flake_ref, version)
  local security = require("security")
  
  -- Validate that it's actually a flake reference
  if not M.is_reference(flake_ref) then
    error("Invalid flake reference")
  end
  
  local parsed = M.parse_reference(flake_ref)
  
  -- Security validation for local flakes
  security.validate_local_flake(flake_ref)

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

  local cmdline = string.format("nix build --no-link --print-out-paths '%s'", build_ref)

  logger.step("Building flake " .. build_ref .. "...")
  local result = shell.exec(cmdline)
  local outputs = {}
  for path in result:gmatch("[^\n]+") do
    table.insert(outputs, path)
  end

  if #outputs == 0 then
    error("No outputs returned by nix build for flake: " .. build_ref)
  end

  return outputs, build_ref
end

return M