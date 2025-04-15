local job = require('plenary.job')
local notify = require('task-runner.notify')

---@class TaskRunner.TaskConfig
---@field command string Command to run
---@field cond? fun(self: TaskRunner.Task): boolean
---@field args? string[] List of arguments to pass
---@field cwd? string Working directory for job
---@field env? table<string, string>|string[] Environment looking like: { ['VAR'] = 'VALUE' } or { 'VAR=VALUE' }
---@field on_stdout? fun(error: string, data: string)

---@class TaskRunner.Task: TaskRunner.TaskConfig
local M = {}

---@param file TaskRunner.TaskConfig
---@param name string
---@return TaskRunner.Task
function M:new(file, name)
	self.name = name
	self.command = file.command
	self.args = file.args or {}
	self.cwd = file.cwd or vim.loop.cwd()
	self.env = file.env or {}
	self.on_stdout = file.on_stdout
		or function(_, data)
			vim.notify(data, vim.log.levels.INFO, {
				title = self.name,
				annote = self.name,
				group = notify.group,
			})
		end
	self.cond = type(file.cond) == 'function' and file.cond
		or function()
			return true
		end

	return setmetatable(self, {
		__index = M,
		__tostring = function()
			return self.name
		end,
	})
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

---@param task TaskRunner.TaskConfig
---@param name string
function M.assert(task, name)
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

return M
