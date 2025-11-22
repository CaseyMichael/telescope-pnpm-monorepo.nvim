local utils = require("pnpm_monorepo.utils")

---@class pnpm_monorepo.UserConfig
---@field silent? boolean Suppress notification messages
---@field autoload_telescope? boolean Automatically load Telescope extension

---@class pnpm_monorepo.InternalConfig
---@field silent boolean
---@field autoload_telescope boolean

local M = {}

---@type table<string, string[]>
M.monorepoVars = {}

---@type string
M.currentMonorepo = vim.fn.getcwd()

---@type string[]
M.currentProjects = {}

---@type pnpm_monorepo.InternalConfig
local default_config = {
	silent = false,
	autoload_telescope = true,
}

---@type pnpm_monorepo.InternalConfig
M.config = vim.deepcopy(default_config)

---Deep merge user config into default config
---@param default pnpm_monorepo.InternalConfig
---@param user pnpm_monorepo.UserConfig
---@return pnpm_monorepo.InternalConfig
local function merge_config(default, user)
	local merged = vim.deepcopy(default)
	if not user then
		return merged
	end

	for k, v in pairs(user) do
		if merged[k] ~= nil then
			merged[k] = v
		end
	end

	return merged
end

---Validate configuration with path-prefixed error messages
---@param path string The path to the field being validated
---@param tbl table The table to validate
---@see vim.validate
---@return boolean is_valid
---@return string|nil error_message
local function validate_path(path, tbl)
	local ok, err = pcall(vim.validate, tbl)
	return ok, err and (path .. "." .. err) or nil
end

---Validate user configuration
---@param cfg pnpm_monorepo.InternalConfig
---@return boolean is_valid
---@return string|nil error_message
local function validate_config(cfg)
	local ok, err = validate_path("pnpm_monorepo.config", {
		silent = { cfg.silent, "boolean" },
		autoload_telescope = { cfg.autoload_telescope, "boolean" },
	})
	return ok, err
end

---Load Telescope extension if available and enabled
local function load_telescope_extension()
	if not M.config.autoload_telescope then
		return
	end

	local has_telescope, telescope = pcall(require, "telescope")
	if has_telescope then
		-- Use pcall to handle cases where extension might already be loaded
		pcall(telescope.load_extension, "pnpm_monorepo")
	end
end

---Setup the plugin with user configuration
---@param user_config? pnpm_monorepo.UserConfig
function M.setup(user_config)
	-- Merge user config with defaults
	local merged_config = merge_config(default_config, user_config)

	-- Validate merged config
	local is_valid, err_msg = validate_config(merged_config)
	if not is_valid then
		vim.notify(
			"pnpm_monorepo: Invalid configuration: " .. (err_msg or "unknown error"),
			vim.log.levels.ERROR
		)
		-- Use default config on validation failure
		merged_config = vim.deepcopy(default_config)
	end

	M.config = merged_config

	vim.opt.autochdir = false

	-- Auto-detect monorepo root from pnpm-workspace.yaml
	M.currentMonorepo = M.detect_monorepo_root()

	-- Auto-detect projects from pnpm-workspace.yaml
	M.load_pnpm_projects()

	-- Load telescope extension if enabled
	load_telescope_extension()

	-- Setup session load autocmd
	vim.api.nvim_create_autocmd("SessionLoadPost", {
		callback = function()
			M.change_monorepo(vim.fn.getcwd())
		end,
	})
end

---Load projects list by auto-detecting from pnpm-workspace.yaml
function M.load_pnpm_projects()
	-- Ensure currentMonorepo is set
	if not M.currentMonorepo or M.currentMonorepo == "" then
		M.currentMonorepo = M.detect_monorepo_root()
	end

	local detected_projects = utils.auto_detect_projects(M.currentMonorepo)
	local projects = {}

	-- Always include root directory as the first option
	table.insert(projects, "/")

	-- Add detected projects if any
	if detected_projects and #detected_projects > 0 then
		for _, project in ipairs(detected_projects) do
			-- Skip root if it was already detected (shouldn't happen, but be safe)
			if project ~= "/" then
				table.insert(projects, project)
			end
		end
	end

	-- Ensure we always have at least the root project
	if #projects == 0 then
		table.insert(projects, "/")
	end

	M.monorepoVars[M.currentMonorepo] = projects
	M.currentProjects = M.monorepoVars[M.currentMonorepo] or projects
end

---Change to a different monorepo
---@param path string Path to the new monorepo
function M.change_monorepo(path)
	-- Auto-detect monorepo root from the provided path
	M.currentMonorepo = M.detect_monorepo_root(path)
	-- Load projects for the new monorepo
	M.load_pnpm_projects()
end

---Detect monorepo root from pnpm-workspace.yaml location
---@param start_path? string Starting path for detection
---@return string
function M.detect_monorepo_root(start_path)
	start_path = start_path or vim.fn.getcwd()
	local workspace_file = utils.find_pnpm_workspace(start_path)
	if workspace_file then
		local Path = require("plenary.path")
		return Path:new(workspace_file):parent().filename
	end
	return start_path
end

return M
