local Log = require('task-runner.logger')
local Manager = require('task-runner.task.manager')
local Picker = require('task-runner.task.picker')

local M = {}

---@param input vim.api.keyset.create_user_command.command_args
function M.execute(input)
   Manager:reload_modules()
   -- Only Tasks was supplied
   -- Use provider to choose which tasks to run
   if input.args:match('^%s*$') then
      Picker.open()
   else -- Tasks <module> <task>
      local ret = M.parse(input.args)
      if ret.module ~= nil then
         if ret.task ~= nil then
            ret.task:run()
         else
            Log.error('No task found!\nNamed: ' .. ret.__task_name)
         end
      else
         Log.error('No module found!\nNamed: ' .. ret.__module_name)
      end
   end
end

---@param input string
function M.parse(input)
   local fragments = vim.split(input, ' ', { plain = true, trimempty = true })
   local module_name, task_name = fragments[1], fragments[2]
   local modules = Manager:get_modules()
   local module = modules[module_name] or nil
   return {
      __modules = modules,
      __fragments = fragments,
      __module_name = module_name,
      __task_name = task_name,
      ---@type string[]
      modules = vim.tbl_keys(modules),
      ---@type TaskRunner.Module?
      module = module,
      ---@type string[]?
      tasks = module ~= nil and vim.tbl_keys(module.tasks) or nil,
      ---@type TaskRunner.Task?
      task = module ~= nil and module.tasks[task_name] or nil,
   }
end

---@param prefix string
---@param line string
---@param col number
function M.complete(prefix, line, col)
   line = line:sub(1, col):match('Tasks%s*(.*)$')
   local ret = M.parse(line)
   local candidates = {} ---@type string[]
   if not ret.module then
      candidates = vim.list_extend(candidates, ret.modules or {})
   else
      candidates = vim.list_extend(candidates, ret.tasks or {})
   end
   candidates = vim.tbl_filter(function(x)
      return tostring(x):find(prefix, 1, true) == 1
   end, candidates)
   table.sort(candidates)
   return candidates
end

return M
