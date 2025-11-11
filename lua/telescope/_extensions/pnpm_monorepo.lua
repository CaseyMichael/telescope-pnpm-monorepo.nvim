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

-- Helper function to create entry maker for projects list
local function create_entry_maker()
	return function(entry)
		return {
			value = entry,
			display = entry,
			ordinal = entry,
		}
	end
end

local function select_project(prompt_bufnr)
	actions.close(prompt_bufnr)
	local selection = action_state.get_selected_entry()
	local monorepo_module = require("pnpm_monorepo")
	
	-- Handle root directory selection
	local target_dir
	if selection.value == "/" then
		target_dir = monorepo_module.currentMonorepo
	else
		target_dir = monorepo_module.currentMonorepo .. "/" .. selection.value
	end
	
	vim.api.nvim_set_current_dir(target_dir)
	utils.notify("Switched to project" .. ": " .. selection.value)
end

local pnpm_monorepo = function(opts)
	-- Default to a larger dropdown theme if no opts provided
	if not opts then
		opts = require("telescope.themes").get_dropdown({
			layout_config = {
				width = 0.60,
				height = 0.60,
				prompt_position = "top",
			},
		})
	end
	local monorepo_module = require("pnpm_monorepo")

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
