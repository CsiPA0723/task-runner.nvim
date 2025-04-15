local Task = require('task-runner.task')

---@class TaskRunner.ModuleConfig
---@field name? string Defaults to the filename
---@field cond? fun(self: TaskRunner.Module): boolean
---@field tasks table<string, TaskRunner.TaskConfig>

---@class TaskRunner.Module: TaskRunner.ModuleConfig
---@field private path string
---@field private hash string
---@field tasks table<string, TaskRunner.Task>
---@field is_valid boolean
local M = {
	tasks = {},
}

---@param file TaskRunner.ModuleConfig
---@param path string
---@param opts TaskRunner.config
---@return TaskRunner.Module
function M:new(file, path, opts)
	self.path = path
	self.hash = vim.fn.sha256(vim.inspect(path))
	self.name = file.name or vim.fn.fnamemodify(path, ':t:r')
	self.cond = type(file.cond) == 'function' and file.cond
		or function()
			return true
		end

	for name, task in pairs(file.tasks) do
		self.tasks[name] = Task:new(task, name)
	end

	return setmetatable(self, {
		__index = M,
		__tostring = function()
			return self.name
		end,
	})
end

function M:check_hash()
	local hash = vim.fn.sha256(vim.inspect(self.path))
	return hash ~= self.hash
end

function M:get_path()
	return self.path
end

---@param file TaskRunner.ModuleConfig
---@param path string
function M.assert(file, path)
	local is_valid = true
	local err = file.name or vim.fn.fnamemodify(path, ':t:r')
	if type(file) ~= 'table' then
		err = err .. '\nModule must be a table'
		is_valid = false
	else
		if file.name and type(file.name) ~= 'string' then
			err = err .. '\nModule.name must be a string'
			is_valid = false
		end
		if file.cond and type(file.cond) ~= 'function' then
			err = err .. '\nModule.cond must be a function'
			is_valid = false
		end
		if type(file.tasks) ~= 'table' then
			err = err .. '\nModule must have a tasks table'
			is_valid = false
		else
			for name, task in pairs(file.tasks) do
				is_valid, err = Task.assert(task, name)
			end
		end
	end
	return is_valid, err
end

return M
