local Notify = require('task-runner.notify')

local M = {
   priority = { 'snacks', 'telescope', 'fzf_lua' },
   provider_modules = {
      snacks = 'snacks.picker',
      telescope = 'telescope.pickers',
      fzf_lua = 'fzf-lua',
   },
   ---@type string?
   provider = nil,
   ---@type table<string, string>
   --- snacks = 'task-runner.providers.snacks',
   --- telescope = 'task-runner.providers.telescope',
   --- fzf_lua = 'task-runner.providers.fzf_lua',
   available_providers = {},
}

---@param opts TaskRunner.config
function M.setup(opts)
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
         vim.notify(
            'No available providers found! Please install one of the following: '
               .. vim.inspect(M.priority),
            vim.log.levels.ERROR,
            { group = Notify.group, timeout = 8000, title = 'Task Picker' }
         )
         M.provider = nil
      else
         local providers = vim.tbl_filter(function(str)
            return str ~= M.provider and M.available_providers[str] ~= nil
         end, M.priority)
         vim.notify(
            M.provider
               .. ' provider is not available. Falling back to '
               .. providers[1],
            vim.log.levels.WARN,
            { group = Notify.group, timeout = 6000, title = 'Task Picker' }
         )
         M.provider = providers[1]
      end
   end
end

function M.open()
   if M.provider == nil then
      return
   end
   local picker_provider = M.available_providers[M.provider]

   local ok, picker = pcall(require, picker_provider)

   if not ok then
      vim.notify(
         'Cannot load ' .. picker_provider .. 'picker',
         vim.log.levels.ERROR,
         { group = Notify.group, title = 'Task Picker' }
      )
      return
   end

   picker.pick()
end

return M
