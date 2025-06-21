local Job = require('plenary.job')
local Log = require('task-runner.logger')

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
         Log.info(data, { title = opts.name, annote = opts.name })
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
   Job:new({
      command = self.command,
      args = self.args,
      cwd = self.cwd,
      env = self.env,
      on_stdout = vim.schedule_wrap(self.on_stdout),
      on_start = vim.schedule_wrap(function()
         Log.info('Started...', {
            title = self.name,
            annote = self.name,
            key = self.name .. 'Job',
         })
      end),
      on_exit = vim.schedule_wrap(function(_, return_val)
         if return_val == 0 then
            Log.info('Finished', {
               title = self.name,
               annote = self.name,
               key = self.name .. 'Job',
            })
         else
            Log.error('Failed', {
               title = self.name,
               annote = self.name,
               key = self.name .. 'Job',
            })
         end
      end),
   }):start()
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
