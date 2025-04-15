local manager = require('task-runner.task.manager')
local picker = require('task-runner.picker')

local M = {}

---@param input vim.api.keyset.create_user_command.command_args
function M.execute(input)
	-- Only Tasks was supplied
	-- Use provider to choose which tasks to run
	if input.args:match('^%s*$') then
		picker.open()
	else -- Tasks <module> <task>
		local ret = M.parse(input.args)
	end
end

---@param input string
function M.parse(input) end

---@param prefix string
---@param line string
---@param col number
function M.complete(prefix, line, col)
	line = line:sub(1, col):match('Tasks%s*(.*)$')
	local ret = M.parse(line)
end

function M.modules() end

function M.complete_tasks() end

return M
