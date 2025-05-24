---@type TaskRunner.ModuleConfig
return {
   name = 'Testing_Module',
   tasks = {
      asder = {
         command = 'echo',
         args = { 'asd' },
      },
      list = {
         command = 'ls',
         args = { '-la' },
         cwd = '~/.config/nvim',
      },
   },
}
