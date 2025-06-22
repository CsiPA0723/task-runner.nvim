local Log = require('task-runner.logger')
local Util = require('task-runner.util')

---@class TaskRunner.Task
---@field private running vim.SystemObj[]
---@field name? string
---@field command string[] Command to run
---@field cond? fun(self: TaskRunner.Task): boolean
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
      command = {},
      cwd = vim.loop.cwd(),
      env = {},
      on_stdout = function(_, data)
         Log.info(data, { title = opts.name, annote = opts.name })
      end,
      cond = function()
         return true
      end,
   }, opts or {})
   opts.running = {}

   setmetatable(opts, self)
   self.__index = self
   return opts
end

function M:run()
   if not self:cond() then
      return
   end
   local notify_opts = {
      title = self.name,
      annote = self.name,
      key = self.name .. 'Job',
   }
   Log.info('Started...', notify_opts)
   local job = vim.system(self.command, {
      cwd = self.cwd,
      env = self.env,
      stdout = self.on_stdout,
   }, function(out)
      if out.code == 0 then
         Log.info('Finished', notify_opts)
      else
         Log.error('Failed: ' .. out.stderr .. (out.stdout or ''), notify_opts)
      end
   end)
end

---@param name string
---@param task TaskRunner.Task
function M.assert(name, task)
   local is_valid = true
   ---@module 'fidget'
   ---@type Options
   local notify_opts = { title = name, annote = name }
   is_valid = is_valid
      and Util.check_type('Command', task.command, 'table', false, notify_opts)
   is_valid = is_valid
      and Util.check_type('Cwd', task.cwd, 'string', true, notify_opts)
   is_valid = is_valid
      and Util.check_type('Env', task.env, 'table', true, notify_opts)
   is_valid = is_valid
      and Util.check_type(
         'On_Stdout',
         task.on_stdout,
         'callable',
         true,
         notify_opts
      )
   is_valid = is_valid
      and Util.check_type('Cond', task.cond, 'callable', true, notify_opts)
   return is_valid
end

function M:__tostring()
   return self.name
end

return M
