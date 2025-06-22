local Task = require('task-runner.task')
local Util = require('task-runner.util')

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
   opts.hash = vim.fn.sha256(vim.inspect(file))
   for name, task in pairs(file.tasks) do
      opts.tasks[name] = Task:new(name, task)
   end

   setmetatable(opts, self)
   self.__index = self
   return opts
end

---@return boolean # true if the module's hash is different
function M:check_hash()
   local is_success, file = pcall(dofile, self.path)
   local hash = nil
   if is_success then
      hash = vim.fn.sha256(vim.inspect(file))
   end
   return hash ~= self.hash and is_success
end

function M:get_path()
   return self.path
end

---@param path string
---@param file TaskRunner.ModuleConfig
function M.assert(path, file)
   local is_valid = true
   local name = file.name or vim.fn.fnamemodify(path, ':t')
   ---@module 'fidget'
   ---@type Options
   local notify_opts = { title = name, annote = name }
   is_valid = is_valid
      and Util.check_type('Module', file, 'table', false, notify_opts)
   if is_valid then
      is_valid = is_valid
         and Util.check_type('Name', file.name, 'string', false, notify_opts)
      is_valid = is_valid
         and Util.check_type('Cond', file.cond, 'callable', true, notify_opts)
      is_valid = is_valid
         and Util.check_type('Tasks', file.tasks, 'table', true, notify_opts)
      if is_valid then
         for task_name, task in pairs(file.tasks) do
            is_valid = is_valid and Task.assert(task_name, task)
         end
      end
   end
   return is_valid
end

function M:__tostring()
   return self.name
end

return M
