vim.api.nvim_create_user_command('Tasks', function(input)
   require('task-runner.command').execute(input)
end, {
   nargs = '*',
   complete = function(...)
      return require('task-runner.command').complete(...)
   end,
   desc = 'Tasks',
})
