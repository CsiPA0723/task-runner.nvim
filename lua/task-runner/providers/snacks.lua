local M = {}

---@type TaskRunner.picker.pick
function M.pick(opts, filter_module)
   local tasks = {} ---@type snacks.picker.finder.Item[]

   ---@param module TaskRunner.Module
   local populate_tasks = function(module)
      for task_name, _ in pairs(module.tasks) do
         tasks[#tasks + 1] = {
            file = module:get_path(),
            text = module.name .. ' > ' .. task_name,
            module_name = module.name,
            task_name = task_name,
         }
      end
   end

   if filter_module ~= nil then
      populate_tasks(filter_module)
   else
      local modules = require('task-runner.task.manager'):get_modules()
      for _, module in pairs(modules) do
         populate_tasks(module)
      end
   end

   local filter_name = filter_module and (' (' .. filter_module.name .. ')')
      or ''

   require('snacks.picker').pick({
      items = tasks,
      title = 'TaskRunner' .. filter_name,
      prompt = 'Run> ',
      show_empty = true,
      -- TODO: Custom format
      format = Snacks.picker.format.text,
      -- TODO: Add cursor positon
      preview = Snacks.picker.preview.file,
      win = {
         input = { keys = { ['<c-e>'] = { 'edit', mode = { 'n', 'i' } } } },
      },
      -- TODO: Sort?
      actions = {
         edit = function(picker, item)
            picker:close()
            vim.cmd.edit(item.file)
         end,
         confirm = function(picker, item)
            picker:close()
            local manager = require('task-runner.task.manager')
            manager:get_module(item.module_name).tasks[item.task_name]:run()
         end,
      },
   })
end

return M
