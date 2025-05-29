local M = {
   provider_modules = {
      snacks = 'snacks.picker',
      telescope = 'telescope.pickers',
      fzf_lua = 'fzf_lua',
   },
   ---@type string
   available_provider = nil,
}

---@param opts TaskRunner.config
function M.setup(opts)
   M.provider = opts.provider
end

function M.open() end

return M
