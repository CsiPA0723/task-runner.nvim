local Log = require('task-runner.logger')
local Module = require('task-runner.module')
local Scan = require('plenary.scandir')

---@class TaskRunner.TaskManager
---@field private opts TaskRunner.config
---@field private modules table<string, TaskRunner.Module>
local M = { opts = {}, modules = {} }

---@param opts TaskRunner.config
function M:setup(opts)
   local dir_stat, err = vim.uv.fs_stat(opts.tasks_dir)
   if dir_stat ~= nil and dir_stat.type == 'directory' then
      self.opts = opts
      M:load_modules(opts)
      require('task-runner.task.picker').setup(opts)
   else
      if err ~= nil then
         Log.error(err)
      end
      Log.error('Failed to setup plugin!')
   end
end

function M:get_modules()
   return self.modules
end

---@param opts? TaskRunner.config
function M:load_modules(opts)
   opts = vim.tbl_extend('force', self.opts, opts or {})
   Log.debug('Loading modules...', { key = Log.keys.module_loading })

   local files = Scan.scan_dir(opts.tasks_dir, { depth = opts.scan_depth or 1 })

   if #files > 0 then
      for _, path in ipairs(files) do
         M:load_module(path, opts)
      end

      Log.debug('Loaded modules!', { key = Log.keys.module_loading })
   else
      Log.warn('No modules found!', { key = Log.keys.module_loading })
   end
end

---@param path string
---@param opts? TaskRunner.config
function M:load_module(path, opts)
   opts = vim.tbl_extend('force', self.opts, opts or {})
   ---@type boolean, TaskRunner.Module
   local is_success, file = pcall(dofile, path)
   if not is_success then
      Log.error('Failed to load module: ' .. file)
   else
      local is_valid, err = Module.assert(path, file)
      if is_valid then
         local module = Module:new(path, file)
         self.modules[module.name] = module
      else
         Log.error('Module is not valid: ' .. err)
      end
   end
end

---@param opts? TaskRunner.config
function M:reload_modules(opts)
   opts = vim.tbl_extend('force', self.opts, opts or {})
   for name, module in pairs(self.modules) do
      if module:check_hash() then
         Log.info('Reloading module: ' .. name)
         M:load_module(module:get_path(), opts)
      end
   end
end

return M
