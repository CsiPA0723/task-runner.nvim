---@type TaskRunner.ModuleConfig
return {
   name = 'Testing_Module',
   tasks = {
      echo = { command = { 'echo', 'Hello World!' } },
      list = {
         command = { 'ls', '-la' },
         cwd = vim.fn.expand(vim.fn.stdpath('config')),
      },
   },
}
