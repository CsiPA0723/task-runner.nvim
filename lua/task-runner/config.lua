---@class TaskRunner.config
local Config = {
	---Default: stdpath('config') .. '/tasks' - (`~/.config/nvim/tasks` on linux usually)
	tasks_dir = vim.fn.stdpath('config') .. '/tasks',
	---The scan depth of the tasks directory when loading the tasks initally (default: 1)
	scan_depth = 1,
}

return Config
