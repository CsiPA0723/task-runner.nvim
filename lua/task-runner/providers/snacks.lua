local M = {}

---@type TaskRunner.picker.pick
function M.pick(opts, modules)
   local tasks = {} ---@type snacks.picker.finder.Item[]

   for module_name, module in pairs(modules) do
      for task_name, task in pairs(module.tasks) do
         tasks[#tasks + 1] = {
            file = module:get_path(),
            text = module_name .. ' > ' .. task_name,
            task = task,
            module = module,
         }
      end
   end

   require('snacks.picker').pick({
      items = tasks,
      title = 'TaskRunner',
      prompt = 'Run> ',
      show_empty = true,
      -- TODO: Custom format
      format = Snacks.picker.format.text,
      -- TODO: Add cursor positon
      preview = Snacks.picker.preview.file,
      win = {
         input = { keys = { ['<c-e>'] = { 'edit', mode = { 'n', 'i' } } } },
      },
      actions = {
         edit = function(picker, item)
            picker:close()
            vim.cmd.edit(item.file)
         end,
         confirm = function(picker, item)
            picker:close()
            item.task:run()
         end,
      },
   })
end

return M
