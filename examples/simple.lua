---@type TaskRunner.ModuleConfig
return {
   name = 'Testing_Module',
   tasks = {
      echo = { command = { 'echo', 'Hello World!' } },
      list = {
         command = { 'eza', '-lhA', '--icons', '--group-directories-first' },
         cwd = vim.fn.expand(vim.fn.stdpath('config')),
         on_stdout = function(err, data)
            vim.schedule(function()
               if err then
                  vim.notify(
                     err,
                     vim.log.levels.ERROR,
                     { group = _G.TaskRunner.config.notification.group }
                  )
               elseif data ~= '' and data ~= nil then
                  local lines = vim.split(data, '\n')
                  local width = math.max(unpack(vim.tbl_map(function(line)
                     return #line
                  end, lines)))
                  local height = #lines

                  local ok = pcall(Snacks.win.new, {
                     title = '[ List ]',
                     title_pos = 'center',
                     border = 'double',
                     ft = 'txt',
                     width = width + 4,
                     height = height,
                     backdrop = 100,
                     text = err or data,
                  })
                  if not ok then
                     vim.notify(
                        'Could not open window',
                        vim.log.levels.ERROR,
                        { group = _G.TaskRunner.config.notification.group }
                     )
                  end
               end
            end)
         end,
      },
   },
}
