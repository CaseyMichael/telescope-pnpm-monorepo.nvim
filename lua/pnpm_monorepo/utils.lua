local Path = require("plenary.path")
local scan_dir = require("plenary.scandir")

local M = {}

---Notify user with message, respecting silent config option
---@param message string Message to display
function M.notify(message)
	local pnpm_monorepo = require("pnpm_monorepo")
	if pnpm_monorepo.config and pnpm_monorepo.config.silent then
		return
	end
	vim.notify(message, vim.log.levels.INFO)
end

---Format a path to ensure it starts with '/' and is normalized
---@param path string|nil Path to format
---@return string Formatted path
function M.format_path(path)
	if not path or path == "" then
		return "/"
	end

	-- Remove trailing slashes
	path = path:gsub("/+$", "")
	if path == "" then
		return "/"
	end

	-- Ensure it starts with /
	if not path:match("^/") then
		path = "/" .. path
	end

	return path
end

---Find pnpm-workspace.yaml by walking up the directory tree
---@param start_path string|nil Starting path for search
---@return string|nil Absolute path to pnpm-workspace.yaml file, or nil if not found
function M.find_pnpm_workspace(start_path)
	start_path = start_path or vim.fn.getcwd()
	
	local ok, current = pcall(Path.new, Path, start_path)
	if not ok or not current then
		return nil
	end

	while current:exists() do
		local workspace_file = current:joinpath("pnpm-workspace.yaml")
		if workspace_file:exists() then
			local abs_path = workspace_file:absolute()
			return abs_path
		end

		local parent = current:parent()
		if not parent or parent.filename == current.filename then
			break
		end
		current = parent
	end

	return nil
end

---Parse pnpm-workspace.yaml file
---Simple YAML parser for the specific structure of pnpm-workspace.yaml
---@param file_path string Path to pnpm-workspace.yaml file
---@return string[]|nil Array of workspace patterns, or nil if parsing fails
function M.parse_pnpm_workspace(file_path)
	local ok, content = pcall(function()
		return Path:new(file_path):read()
	end)
	
	if not ok or not content then
		return nil
	end

	local patterns = {}
	local in_packages = false

	for line in content:gmatch("[^\r\n]+") do
		-- Remove leading/trailing whitespace
		line = line:match("^%s*(.-)%s*$")

		-- Check if we're in the packages section
		if line:match("^packages:") then
			in_packages = true
		elseif line:match("^[^%s-]") and in_packages then
			-- If we hit a non-indented line, we're out of packages section
			break
		elseif in_packages and line:match("^%s*-") then
			-- Extract the pattern (remove leading -, whitespace, and quotes)
			local pattern = line:match("^%s*-%s*['\"](.+)['\"]")
			if not pattern then
				pattern = line:match("^%s*-%s*(.+)")
				if pattern then
					pattern = pattern:match("^%s*(.-)%s*$")
				end
			end
			if pattern and pattern ~= "" then
				table.insert(patterns, pattern)
			end
		end
	end

	return #patterns > 0 and patterns or nil
end

---Directories that should never be treated as packages
---@type string[]
local excluded_dirs = {
	".github",
	".git",
	"node_modules",
	".vscode",
	".idea",
	"dist",
	"build",
	".next",
	".nuxt",
	".cache",
	"coverage",
	".nyc_output",
}

---Check if directory name should be excluded
---@param dir_name string Directory name to check
---@return boolean True if directory should be excluded
local function is_excluded_dir(dir_name)
	for _, excluded in ipairs(excluded_dirs) do
		if dir_name == excluded then
			return true
		end
	end
	return false
end

---Check if directory is a valid package (has package.json)
---@param dir_path Path Path object to check
---@return boolean True if directory contains package.json
local function is_valid_package(dir_path)
	local package_json = dir_path:joinpath("package.json")
	return package_json:exists()
end

---Convert glob pattern to lua pattern
---@param glob string Glob pattern (e.g., "apps/*")
---@return string Lua pattern
local function glob_to_lua_pattern(glob)
	return "^" .. glob:gsub("[%(%)%.%+%-%*%?%[%]%^%$%%]", "%%%0"):gsub("%%%*", ".*") .. "$"
end

---Add path to results if valid
---@param dir_path Path Path object to add
---@param monorepo_root string Root path of monorepo
---@param resolved_paths string[] Array to add path to
---@param seen table<string, boolean> Set of already seen paths
local function add_if_valid(dir_path, monorepo_root, resolved_paths, seen)
	-- Get the directory name (last component of path)
	-- Try to get it from the relative path first, fallback to filename
	local relative_path = dir_path:make_relative(monorepo_root)
	if not relative_path or relative_path == "" then
		return
	end

	-- Extract directory name from relative path
	local dir_name = relative_path:match("([^/\\]+)$")
	if dir_name and is_excluded_dir(dir_name) then
		return
	end

	if not is_valid_package(dir_path) then
		return
	end

	local formatted_path = M.format_path(relative_path)
	if not seen[formatted_path] then
		table.insert(resolved_paths, formatted_path)
		seen[formatted_path] = true
	end
end

---Resolve workspace patterns to actual directory paths
---Patterns like 'apps/*' or 'packages/*' are resolved to actual directories
---@param monorepo_root string Root path of monorepo
---@param patterns string[] Array of workspace patterns
---@return string[] Array of resolved project paths
function M.resolve_workspace_patterns(monorepo_root, patterns)
	local resolved_paths = {}
	local seen = {}

	for _, pattern in ipairs(patterns) do
		-- Remove quotes if present
		pattern = pattern:gsub("^['\"](.+)['\"]$", "%1")

		if pattern:match("%*") then
			-- Wildcard pattern: e.g., 'apps/*'
			local base_dir = pattern:match("^(.+)/%*$")
			if base_dir then
				local base_path = Path:new(monorepo_root):joinpath(base_dir)
				if base_path:exists() and base_path:is_dir() then
					local success, entries = pcall(function()
						return scan_dir.scan_dir(base_path.filename, { only_dirs = true, depth = 1 })
					end)

					if success and entries then
						local lua_pattern = glob_to_lua_pattern(pattern)
						for _, entry in ipairs(entries) do
							local entry_path = Path:new(entry)
							local relative_path = entry_path:make_relative(monorepo_root)
							if relative_path and relative_path:match(lua_pattern) then
								add_if_valid(entry_path, monorepo_root, resolved_paths, seen)
							end
						end
					end
				end
			end
		else
			-- Exact path pattern
			local exact_path = Path:new(monorepo_root):joinpath(pattern)
			if exact_path:exists() and exact_path:is_dir() then
				add_if_valid(exact_path, monorepo_root, resolved_paths, seen)
			end
		end
	end

	table.sort(resolved_paths)
	return resolved_paths
end

---Auto-detect projects from pnpm-workspace.yaml
---@param monorepo_root string Root path of monorepo
---@return string[]|nil Array of detected project paths, or nil if detection fails
function M.auto_detect_projects(monorepo_root)
	local workspace_file = M.find_pnpm_workspace(monorepo_root)
	if not workspace_file then
		return nil
	end

	local patterns = M.parse_pnpm_workspace(workspace_file)
	if not patterns then
		return nil
	end

	local projects = M.resolve_workspace_patterns(monorepo_root, patterns)
	return #projects > 0 and projects or nil
end

return M
