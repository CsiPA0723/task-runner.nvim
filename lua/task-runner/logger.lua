local M = {
   group = 'TaskRunner',
   keys = {
      module_loading = 'TaskRunnerModuleLoading',
      module_reload = 'TaskRunnerModuleReload',
   },
}

---@module 'fidget'

---@param msg string
---@param level vim.log.levels
---@param opts Options?
local function log(msg, level, opts)
   opts = vim.tbl_deep_extend('force', { group = M.group }, opts or {})
   vim.notify(msg, level, opts)
end

---@param msg string
---@param opts Options?
function M.info(msg, opts)
   log(msg, vim.log.levels.INFO, opts)
end

---@param msg string
---@param opts Options?
function M.warn(msg, opts)
   log(msg, vim.log.levels.WARN, opts)
end

---@param msg string
---@param opts Options?
function M.error(msg, opts)
   log(msg, vim.log.levels.ERROR, opts)
end

---@param msg string
---@param opts Options?
function M.debug(msg, opts)
   log(msg, vim.log.levels.DEBUG, opts)
end

return M
