local L = require('task-runner.logger')
local M = {}

---@module 'fidget'
---@param name string Name of the variable
---@param val any Value to check
---@param ref any Reference type string or object
---@param allow_nil boolean Allow nil values
---@param opts Options? If not nil, triggers error notification
---@return boolean, string
function M.check_type(name, val, ref, allow_nil, opts)
   local ok = M.assert(val, ref, allow_nil)
   local err = string.format('`%s` should be %s, not %s', name, ref, type(val))
   if not ok and opts then
      L.error(err, opts)
   end
   return ok, err
end

---@param val any Value to check
---@param ref any Reference type string or object
---@param allow_nil boolean Allow nil values
---@return boolean
function M.assert(val, ref, allow_nil)
   return type(val) == ref
      or (ref == 'callable' and vim.is_callable(val))
      or (allow_nil and val == nil)
end

return M
