local job = require('plenary.job')
local notify = require('task-runner.notify')

---@class TaskRunner.Task
---@field name? string
---@field command string Command to run
---@field cond? fun(self: TaskRunner.Task): boolean
---@field args? string[] List of arguments to pass
---@field cwd? string Working directory for job
---@field env? table<string, string>|string[] Environment looking like: { ['VAR'] = 'VALUE' } or { 'VAR=VALUE' }
---@field on_stdout? fun(error: string, data: string)

---@class TaskRunner.Task
local M = {}

---@param name string
---@param opts TaskRunner.Task
function M:new(name, opts)
	opts = vim.tbl_deep_extend('force', {
		name = name,
		args = {},
		cwd = vim.loop.cwd(),
		env = {},
		on_stdout = function(_, data)
			vim.notify(data, vim.log.levels.INFO, {
				title = opts.name,
				annote = opts.name,
				group = notify.group,
			})
		end,
		cond = function()
			return true
		end,
	}, opts or {})

	setmetatable(opts, self)
	self.__index = self
	return opts
end

function M:run()
	job
		:new({
			command = self.command,
			args = self.args,
			cwd = self.cwd,
			env = self.env,
			on_stdout = vim.schedule_wrap(self.on_stdout),
			on_start = vim.schedule_wrap(function()
				vim.notify('Started...', vim.log.levels.INFO, {
					title = self.name,
					annote = self.name,
					key = self.name .. 'Job',
					group = notify.group,
				})
			end),
			on_exit = vim.schedule_wrap(function(_, return_val)
				if return_val == 0 then
					vim.notify('Finished', vim.log.levels.INFO, {
						title = self.name,
						annote = self.name,
						key = self.name .. 'Job',
						group = notify.group,
					})
				else
					vim.notify('Failed', vim.log.levels.ERROR, {
						title = self.name,
						annote = self.name,
						key = self.name .. 'Job',
						group = notify.group,
					})
				end
			end),
		})
		:start()
end

---@param name string
---@param task TaskRunner.Task
function M.assert(name, task)
	local is_valid = true
	local err = name
	if type(task.command) ~= 'string' then
		err = err .. '\nTask must have a command string'
		is_valid = false
	end
	if task.args and type(task.args) ~= 'table' then
		err = err .. '\nTask args must be a table'
		is_valid = false
	end
	if task.cwd and type(task.cwd) ~= 'string' then
		err = err .. '\nTask cwd must be a string'
		is_valid = false
	end
	return is_valid, err
end

function M:__tostring()
	return self.name
end

return M
