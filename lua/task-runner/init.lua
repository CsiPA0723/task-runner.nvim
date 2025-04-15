local M = {}

M.default_config = require('task-runner.config')
M.config = M.default_config

local TaskManager = require('task-runner.task.manager')

---@param opts? TaskRunner.config
function M.setup(opts)
	M.config = vim.tbl_deep_extend('force', M.default_config, opts or {})
	TaskManager:setup(M.config)
end

vim.api.nvim_create_user_command('Tasks', function() end, {})

return M
