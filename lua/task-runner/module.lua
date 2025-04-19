local Task = require('task-runner.task')

---@class TaskRunner.ModuleConfig
---@field name? string Defaults to the filename
---@field cond? fun(self: TaskRunner.Module): boolean
---@field tasks table<string, any>

---@class TaskRunner.Module: TaskRunner.ModuleConfig
---@field private path string
---@field private hash string
---@field tasks table<string, TaskRunner.Task>
---@field is_valid boolean
local M = { tasks = {} }

---@param path string
---@param file TaskRunner.ModuleConfig
---@param opts? TaskRunner.Module
---@return TaskRunner.Module
function M:new(path, file, opts)
	opts = vim.tbl_deep_extend('force', {
		name = file.name,
		tasks = {},
		cond = type(file.cond) == 'function' and file.cond or function()
			return true
		end,
	}, opts or {})

	opts.path = path
	opts.hash = vim.fn.sha256(vim.inspect(path))
	for name, task in pairs(file.tasks) do
		opts.tasks[name] = Task:new(name, task)
	end

	setmetatable(opts, self)
	self.__index = self
	return opts
end

--- Returns true if the module's hash is different
function M:check_hash()
	local hash = vim.fn.sha256(vim.inspect(self.path))
	return hash ~= self.hash
end

function M:get_path()
	return self.path
end

---@param path string
---@param file TaskRunner.ModuleConfig
function M.assert(path, file)
	local is_valid = true
	local err = file.name or vim.fn.fnamemodify(path, ':t')
	if type(file) ~= 'table' then
		err = err .. '\nModule must be a table'
		is_valid = false
	else
		if file.name and type(file.name) == 'string' then
			if string.match(file.name, '%s') ~= nil then
				err = err .. '\nModule.name cannot contain any whitespace characters'
				is_valid = false
			end
		else
			err = err .. '\nModule.name must be set and be a string'
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
				local new_is_valid, new_err = Task.assert(name, task)
				is_valid = is_valid and new_is_valid
				if not new_is_valid then
					err = err .. '\n' .. new_err
				end
			end
		end
	end
	return is_valid, err
end

function M:__tostring()
	return self.name
end

return M
