local Log = require('task-runner.logger')
local Manager = require('task-runner.task.manager')

---@alias TaskRunner.picker.pick fun(opts: TaskRunner.config, module?: TaskRunner.Module)
---@alias TaskRunner.picker.providers 'snacks'|'telescope'|'fzf_lua'|'mini'

---@class TaskRunner.picker
---@field provider? TaskRunner.picker.providers
---@field available_providers table<TaskRunner.picker.providers, string>
local M = {
   priority = { 'snacks', 'telescope', 'fzf_lua', 'mini' },
   provider_modules = {
      snacks = 'snacks.picker',
      telescope = 'telescope.pickers',
      fzf_lua = 'fzf-lua',
      mini = 'mini.picker',
   },
   provider = nil,
   --- Possible providers
   --- ```lua
   --- {
   ---   snacks = 'task-runner.providers.snacks',
   ---   telescope = 'task-runner.providers.telescope',
   ---   fzf_lua = 'task-runner.providers.fzf_lua',
   ---   mini = 'task-runner.providers.mini',
   --- }
   --- ```
   available_providers = {},
}

---@param opts TaskRunner.config
function M.setup(opts)
   M.config = opts
   M.provider = opts.provider

   local found = false
   for provider, module in pairs(M.provider_modules) do
      local ok = pcall(require, module)
      if ok then
         M.available_providers[provider] = 'task-runner.providers.' .. provider
         found = found or M.provider == provider
      end
   end

   if not found then
      if vim.tbl_count(M.available_providers) == 0 then
         Log.error(
            'No available providers found! Please install one of the following: '
               .. vim.inspect(M.priority)
         )
         M.provider = nil
      else
         local providers = vim.tbl_filter(function(str)
            return str ~= M.provider and M.available_providers[str] ~= nil
         end, M.priority)
         Log.warn(
            M.config.provider
               .. ' provider is not available. Falling back to '
               .. providers[1],
            { timeout = 6000, title = 'Task Picker' }
         )
         M.provider = providers[1]
      end
   end
end

---@param module? TaskRunner.Module
function M.open(module)
   if M.provider == nil then
      return
   end
   ---@type string
   local picker_provider = M.available_providers[M.provider]

   ---@type boolean, { pick: TaskRunner.picker.pick }
   local ok, picker = pcall(require, picker_provider)

   if not ok then
      Log.error(
         'Cannot load ' .. picker_provider .. 'picker',
         { title = 'Task Picker' }
      )
      return
   end

   picker.pick(M.config, module)
end

return M
