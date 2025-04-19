local Module = require('task-runner.module')
local notify = require('task-runner.notify')
local scan = require('plenary.scandir')

---@class TaskRunner.TaskManager
---@field private opts TaskRunner.config
---@field private modules table<string, TaskRunner.Module>
local M = { opts = {}, modules = {} }

---@param opts TaskRunner.config
function M:setup(opts)
	local dir_stat, err = vim.uv.fs_stat(opts.tasks_dir)
	if dir_stat ~= nil and dir_stat.type == 'directory' then
		self.opts = opts
		M:load_modules(opts)

		vim.api.nvim_create_user_command('Tasks', function(input)
			require('task-runner.command').execute(input)
		end, {
			nargs = '*',
			complete = function(...)
				return require('task-runner.command').complete(...)
			end,
			desc = 'Tasks',
		})
	else
		if err ~= nil then
			vim.notify(err, vim.log.levels.ERROR, { group = notify.group })
		end
		vim.notify(
			'Failed to setup plugin!',
			vim.log.levels.ERROR,
			{ group = notify.group }
		)
	end
end

function M:get_modules()
	return self.modules
end

---@param opts? TaskRunner.config
function M:load_modules(opts)
	opts = vim.tbl_extend('force', self.opts, opts or {})
	vim.notify(
		'Loading modules...',
		vim.log.levels.INFO,
		{ key = notify.keys.module_loading, group = notify.group }
	)

	local files = scan.scan_dir(opts.tasks_dir, {
		depth = opts.scan_depth or 1,
	})

	for _, path in ipairs(files) do
		M:load_module(path, opts)
	end

	vim.notify(
		'Loaded modules!',
		vim.log.levels.INFO,
		{ key = notify.keys.module_loading, group = notify.group }
	)
end

---@param path string
---@param opts? TaskRunner.config
function M:load_module(path, opts)
	opts = vim.tbl_extend('force', self.opts, opts or {})
	---@type boolean, TaskRunner.Module
	local is_success, file = pcall(dofile, path)
	if not is_success then
		vim.notify(
			'Module loading failed: ' .. file,
			vim.log.levels.ERROR,
			{ group = notify.group }
		)
	else
		local is_valid, err = Module.assert(path, file)
		if is_valid then
			local module = Module:new(path, file)
			self.modules[module.name] = module
		else
			vim.notify(
				'Module is not valid: ' .. err,
				vim.log.levels.ERROR,
				{ group = notify.group }
			)
		end
	end
end

---@param opts? TaskRunner.config
function M:reload_modules(opts)
	opts = vim.tbl_extend('force', self.opts, opts or {})
	for name, module in pairs(self.modules) do
		if module:check_hash() then
			vim.notify(
				'Reloading module: ' .. name,
				vim.log.levels.INFO,
				{ group = notify.group }
			)
			M:load_module(module:get_path(), opts)
		end
	end
end

return M
