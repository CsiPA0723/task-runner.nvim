local M = {}

M.config = require('task-runner.config')
local TaskManager = require('task-runner.task.manager')

---@param opts? TaskRunner.config
function M.setup(opts)
   M.config = vim.tbl_deep_extend('force', M.config, opts or {})
   TaskManager:setup(M.config)
end

return M
