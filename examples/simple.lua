---@type TaskRunner.ModuleConfig
return {
   name = 'Testing_Module',
   tasks = {
      echo = {
         command = 'echo',
         args = { 'Hello World!' },
      },
      list = {
         command = 'ls',
         args = { '-la' },
         cwd = vim.fn.expand(vim.fn.stdpath('config')),
      },
   },
}
