---@type boolean
local has_telescope, telescope = pcall(require, "telescope")

if not has_telescope then
	return
end

local finders = require("telescope.finders")
local conf = require("telescope.config").values
local pickers = require("telescope.pickers")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

local utils = require("pnpm_monorepo.utils")

---Create entry maker for projects list
---@return fun(entry: string): table
local function create_entry_maker()
	return function(entry)
		return {
			value = entry,
			display = entry,
			ordinal = entry,
		}
	end
end

---Select project and change directory
---@param prompt_bufnr number Prompt buffer number
local function select_project(prompt_bufnr)
	actions.close(prompt_bufnr)
	local selection = action_state.get_selected_entry()
	if not selection then
		return
	end

	local monorepo_module = require("pnpm_monorepo")

	-- Handle root directory selection
	local target_dir
	if selection.value == "/" then
		target_dir = monorepo_module.currentMonorepo
	else
		target_dir = monorepo_module.currentMonorepo .. "/" .. selection.value
	end

	local ok = pcall(vim.api.nvim_set_current_dir, target_dir)
	if ok then
		utils.notify("Switched to project: " .. selection.value)
	else
		vim.notify(
			"pnpm_monorepo: Failed to change directory to " .. target_dir,
			vim.log.levels.ERROR
		)
	end
end

---Open pnpm monorepo projects picker
---@param opts? table Telescope options (merged with config.telescope_opts)
local function pnpm_monorepo(opts)
	local monorepo_module = require("pnpm_monorepo")
	
	-- Get telescope_opts from plugin config
	local config_telescope_opts = monorepo_module.config and monorepo_module.config.telescope_opts or {}
	
	-- Default to a larger dropdown theme with prompt at top
	local default_opts = require("telescope.themes").get_dropdown({
		layout_config = {
			width = 0.60,
			height = 0.60,
			prompt_position = "top",
		},
	})
	
	-- Merge in order: defaults -> config.telescope_opts -> runtime opts
	opts = opts or {}
	opts = vim.tbl_deep_extend("force", default_opts, config_telescope_opts, opts)
	
	-- Ensure prompt_position defaults to "top" if not explicitly set
	if not opts.layout_config then
		opts.layout_config = {}
	end
	if opts.layout_config.prompt_position == nil then
		opts.layout_config.prompt_position = "top"
	end

	-- Ensure projects are loaded - reload if empty or nil
	if not monorepo_module.currentProjects or #monorepo_module.currentProjects == 0 then
		-- Try to reload projects
		monorepo_module.currentMonorepo = monorepo_module.detect_monorepo_root()
		monorepo_module.load_pnpm_projects()
	end

	-- Check again after reload attempt
	if not monorepo_module.currentProjects or #monorepo_module.currentProjects == 0 then
		local workspace_file = require("pnpm_monorepo.utils").find_pnpm_workspace()
		if not workspace_file then
			vim.notify(
				"pnpm_monorepo: No pnpm-workspace.yaml found. Make sure you're in a pnpm monorepo.",
				vim.log.levels.ERROR
			)
		else
			vim.notify(
				"pnpm_monorepo: No projects detected. Check your pnpm-workspace.yaml patterns and ensure projects have package.json files.",
				vim.log.levels.WARN
			)
		end
		return
	end

	pickers
		.new(opts, {
			prompt_title = "Projects - " .. monorepo_module.currentMonorepo,
			finder = finders.new_table({
				results = monorepo_module.currentProjects,
				entry_maker = create_entry_maker(),
			}),
			sorter = conf.file_sorter(opts),
			attach_mappings = function(prompt_bufnr, map)
				actions.select_default:replace(select_project)
				return true
			end,
		})
		:find()
end

return telescope.register_extension({
	exports = {
		pnpm_monorepo = pnpm_monorepo,
	},
})
