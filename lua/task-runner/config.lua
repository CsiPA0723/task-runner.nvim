---@class TaskRunner.config
---@field tasks_dir? string
---@field scan_depth? integer
---@field provider? 'snacks'|'telescope'|'fzf_lua'|'mini'
local Config = {
   ---Default: stdpath('config') .. '/tasks' - (`~/.config/nvim/tasks` on linux usually)
   tasks_dir = vim.fn.stdpath('config') .. '/tasks',
   ---Preferred provider: snacks (default) | telescope | fzf_lua | mini
   provider = 'snacks',
}

return Config
