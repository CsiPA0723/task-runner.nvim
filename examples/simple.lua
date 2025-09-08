---@type TaskRunner.ModuleConfig
return {
   name = 'Example_Simple',
   tasks = {
      echo = { command = 'echo', args = { 'Hello World!' } },
      list = {
         command = 'eza',
         args = {
            '-lhA',
            '--icons',
            '--group-directories-first',
            '.',
         },
         cwd = vim.fn.expand(vim.fn.stdpath('config')),
         on_stdout = function(data)
            local title = '[ List ]'
            local lines = vim.split(data or 'Empty', '\n')

            local ok = pcall(Snacks.win.new, {
               title = title,
               title_pos = 'center',
               border = 'double',
               ft = 'txt',
               width = function()
                  local width = math.max(unpack(vim.tbl_map(function(line)
                     return #line
                  end, lines)))
                  return width + #title - width % 2
               end,
               height = #lines,
               backdrop = 100,
               text = lines,
            })

            if not ok then
               vim.notify(
                  'Could not open window',
                  vim.log.levels.ERROR,
                  { group = _G.TaskRunner.config.notification.group }
               )
            end
         end,
      },
      stylua = {
         command = vim.fn.expand('~/.local/share/nvim/mason/bin/stylua'),
         args = { vim.fn.expand('%:p') },
      },
   },
}
