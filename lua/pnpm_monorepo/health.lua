local health = vim.health

if not health then
	return {
		check = function()
			vim.notify("pnpm_monorepo: Health checks require Neovim 0.9.0 or higher", vim.log.levels.WARN)
		end,
	}
end

local M = {}

---Check if a module can be required
---@param module_name string Module name to check
---@return boolean success
---@return any|nil module
local function check_module(module_name)
	return pcall(require, module_name)
end

---Validate configuration
local function check_config()
	health.start("Configuration")

	local pnpm_monorepo = require("pnpm_monorepo")
	if not pnpm_monorepo then
		health.error("Plugin module not found")
		return
	end

	local config = pnpm_monorepo.config
	if not config then
		health.error("Configuration not initialized. Run :lua require('pnpm_monorepo').setup()")
		return
	end

	-- Validate config fields
	local ok_silent, err_silent = pcall(vim.validate, {
		silent = { config.silent, "boolean" },
	})
	if not ok_silent then
		health.error("Invalid config.silent: " .. (err_silent or "unknown error"))
	else
		health.ok("config.silent: " .. tostring(config.silent))
	end

	local ok_autoload, err_autoload = pcall(vim.validate, {
		autoload_telescope = { config.autoload_telescope, "boolean" },
	})
	if not ok_autoload then
		health.error("Invalid config.autoload_telescope: " .. (err_autoload or "unknown error"))
	else
		health.ok("config.autoload_telescope: " .. tostring(config.autoload_telescope))
	end
end

---Check required dependencies
local function check_dependencies()
	health.start("Dependencies")

	-- Check plenary.nvim (required)
	local has_plenary, plenary = check_module("plenary")
	if has_plenary then
		local has_path = pcall(function()
			return plenary.path
		end)
		local has_scandir = pcall(function()
			return plenary.scandir
		end)

		if has_path and has_scandir then
			health.ok("plenary.nvim: available")
		else
			health.error("plenary.nvim: missing required modules (path or scandir)")
		end
	else
		health.error("plenary.nvim: not found (required)")
	end

	-- Check telescope.nvim (optional)
	local has_telescope, telescope = check_module("telescope")
	if has_telescope then
		health.ok("telescope.nvim: available (optional)")
	else
		health.warn("telescope.nvim: not found (optional, required for picker functionality)")
	end
end

---Check monorepo detection
local function check_monorepo()
	health.start("Monorepo Detection")

	local pnpm_monorepo = require("pnpm_monorepo")
	if not pnpm_monorepo then
		return
	end

	local current_monorepo = pnpm_monorepo.currentMonorepo
	if not current_monorepo then
		health.warn("No monorepo detected")
		return
	end

	health.ok("Current monorepo: " .. current_monorepo)

	-- Check if pnpm-workspace.yaml exists
	local utils = require("pnpm_monorepo.utils")
	local workspace_file = utils.find_pnpm_workspace(current_monorepo)
	if workspace_file then
		health.ok("pnpm-workspace.yaml found: " .. workspace_file)
	else
		health.warn("pnpm-workspace.yaml not found in " .. current_monorepo)
	end
end

---Check project loading
local function check_projects()
	health.start("Project Loading")

	local pnpm_monorepo = require("pnpm_monorepo")
	if not pnpm_monorepo then
		return
	end

	local projects = pnpm_monorepo.currentProjects
	if not projects then
		health.warn("No projects loaded")
		return
	end

	local project_count = #projects
	if project_count == 0 then
		health.warn("No projects detected")
	else
		health.ok("Projects detected: " .. project_count)
		if project_count > 0 and project_count <= 5 then
			for i, project in ipairs(projects) do
				health.info("  " .. i .. ". " .. project)
			end
		elseif project_count > 5 then
			for i = 1, 5 do
				health.info("  " .. i .. ". " .. projects[i])
			end
			health.info("  ... and " .. (project_count - 5) .. " more")
		end
	end
end

---Check telescope extension
local function check_telescope_extension()
	health.start("Telescope Extension")

	local has_telescope, telescope = check_module("telescope")
	if not has_telescope then
		health.warn("Telescope not available, extension check skipped")
		return
	end

	-- Check if extension is registered
	local extensions = telescope.extensions or {}
	if extensions.pnpm_monorepo then
		health.ok("Extension registered: telescope.extensions.pnpm_monorepo")
	else
		health.warn("Extension not registered. Run :Telescope pnpm_monorepo or require('telescope').load_extension('pnpm_monorepo')")
	end
end

---Run all health checks
function M.check()
	check_config()
	check_dependencies()
	check_monorepo()
	check_projects()
	check_telescope_extension()
end

return M
