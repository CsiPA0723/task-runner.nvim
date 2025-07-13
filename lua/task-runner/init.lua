local TaskRunner = {}
local H = {
   ---@type table<string, TaskRunner.Module>
   modules = nil,
   priority = { 'snacks', 'telescope', 'fzf_lua', 'mini' },
   provider_modules = {
      snacks = 'snacks.picker',
      telescope = 'telescope.pickers',
      fzf_lua = 'fzf-lua',
      mini = 'mini.picker',
   },
   ---@type string?
   picker = nil,
}

---@module 'fidget'
---@alias TaskRunner.picker fun(opts: TaskRunner.config, module?: TaskRunner.Module)
---@alias TaskRunner.providers 'snacks'|'telescope'|'fzf_lua'|'mini'

function TaskRunner.setup(config)
   -- Export module
   _G.TaskRunner = TaskRunner

   -- Setup config
   config = H.setup_config(config)

   -- Apply config
   H.apply_config(config)

   TaskRunner.load_modules()

   vim.api.nvim_create_user_command('Tasks', function(input)
      require('task-runner').execute(input)
   end, {
      nargs = '*',
      complete = function(...)
         return require('task-runner').complete(...)
      end,
      desc = 'Tasks',
   })
end

---@class TaskRunner.config
TaskRunner.config = {
   options = {
      ---Default: stdpath('config') .. '/tasks' - (`~/.config/nvim/tasks` on linux usually)
      tasks_dir = vim.fn.stdpath('config') .. '/tasks',
      ---Preferred provider: snacks (default) | telescope | fzf_lua | mini
      ---@type TaskRunner.providers
      provider = 'snacks',
   },
   ---Fidget notification options
   notification = {
      title = 'TaskRunner',
      group = 'TaskRunner',
      keys = {
         module_loading = 'TaskRunnerModuleLoading',
         module_reload = 'TaskRunnerModuleReload',
      },
   },
}

function TaskRunner.get_modules()
   TaskRunner.check_modules()
   return H.modules
end

function TaskRunner.check_modules()
   local key = H.get_config().notification.keys.module_reload
   local dir_stat, err = vim.uv.fs_stat(TaskRunner.config.options.tasks_dir)
   if dir_stat ~= nil and dir_stat.type == 'directory' then
      if H.modules == nil then
         TaskRunner.load_modules()
      else
         for _, module in pairs(H.modules) do
            if module:check_hash() then
               local path = module:get_path()
               local name = vim.fn.fnamemodify(path, ':t')
               H.log(
                  'Reloading module: ' .. name,
                  vim.log.levels.INFO,
                  { key = key .. name }
               )
               TaskRunner.load_module(module:get_path())
               H.log(
                  'Reloaded module: ' .. name,
                  vim.log.levels.INFO,
                  { key = key .. name }
               )
            end
         end
      end
   else
      H.log(err or 'Directory not accessable!', vim.log.levels.ERROR)
   end
end

function TaskRunner.load_modules()
   H.modules = {}
   local config = H.get_config()

   H.log(
      'Loading modules...',
      vim.log.levels.DEBUG,
      { key = config.notification.keys.module_loading }
   )

   local files = vim.fn.glob(config.options.tasks_dir .. '/*.lua', false, true)

   if #files > 0 then
      for _, path in ipairs(files) do
         TaskRunner.load_module(path)
      end
      H.log(
         'Loaded modules!',
         vim.log.levels.DEBUG,
         { key = config.notification.keys.module_loading }
      )
   else
      H.log(
         'No modules found!',
         vim.log.levels.WARN,
         { key = config.notification.keys.module_loading }
      )
   end
end

---@param path string
function TaskRunner.load_module(path)
   local key = H.get_config().notification.keys.module_reload
   ---@type boolean, TaskRunner.Module
   local is_success, file = pcall(dofile, path)
   if not is_success then
      local name = vim.fn.fnamemodify(path, ':t')
      H.log(
         'Failed to load module: ' .. file,
         vim.log.levels.ERROR,
         { key = key .. name }
      )
   else
      H.Module.assert(path, file)
      local module = H.Module:new(path, file)
      H.modules[module.name] = module
   end
end

---@param input vim.api.keyset.create_user_command.command_args
function TaskRunner.execute(input)
   TaskRunner.check_modules()
   -- Only Tasks was supplied
   -- Use provider to choose which tasks to run
   if input.args:match('^%s*$') then
      TaskRunner.pick()
   else -- Tasks <module> <task>
      local ret = H.parse(input.args)
      if ret.module ~= nil then
         if ret.task ~= nil then
            ret.task:run()
         elseif ret.__task_name ~= nil then
            H.log(
               'No task found!\nNamed: ' .. ret.__task_name,
               vim.log.levels.ERROR
            )
         else
            TaskRunner.pick(ret.module)
         end
      else
         H.log(
            'No module found!\nNamed: ' .. ret.__module_name,
            vim.log.levels.ERROR
         )
      end
   end
end

---@param prefix string
---@param line string
---@param col number
---@return string[]
function TaskRunner.complete(prefix, line, col)
   line = line:sub(1, col):match('Tasks%s*(.*)$')
   local ret = H.parse(line)
   local candidates = {} ---@type string[]
   if not ret.module then
      candidates = vim.list_extend(candidates, ret.modules or {})
   else
      candidates = vim.list_extend(candidates, ret.tasks or {})
   end
   candidates = vim.tbl_filter(function(x)
      return tostring(x):find(prefix, 1, true) == 1
   end, candidates)
   table.sort(candidates)
   return candidates
end

---@param module? TaskRunner.Module
function TaskRunner.pick(module)
   H.search_providers()
   if H.picker == nil then
      return
   end

   ---@type boolean, { pick: TaskRunner.picker }
   local ok, picker = pcall(require, H.picker)

   if not ok then
      H.log(
         'Cannot load ' .. H.picker .. 'picker',
         vim.log.levels.ERROR,
         { title = 'Task Picker' }
      )
      return
   end

   picker.pick(H.get_config(), module)
end

H.default_config = vim.deepcopy(TaskRunner.config)

---@param config? TaskRunner.config
function H.setup_config(config)
   H.check_type('config', config, 'table', true)
   config =
      vim.tbl_deep_extend('force', vim.deepcopy(H.default_config), config or {})
   H.check_type('config.options.tasks_dir', config.options.tasks_dir, 'string')
   H.check_type('config.options.provider', config.options.provider, 'string')

   H.check_type('config.notification', config.notification, 'table')
   H.check_type(
      'config.notification.group',
      config.notification.group,
      'string'
   )
   H.check_type('config.notification.keys', config.notification.keys, 'table')
   H.check_type(
      'config.notification.keys.module_loading',
      config.notification.keys.module_loading,
      'string'
   )
   H.check_type(
      'config.notification.keys.module_reload',
      config.notification.keys.module_reload,
      'string'
   )

   return config
end

---@param config TaskRunner.config
function H.apply_config(config)
   TaskRunner.config = config

   H.is_disabled = function()
      return vim.g.taskrunner_disable == true
         or vim.b.taskrunner_disable == true
   end

   ---@param config? TaskRunner.config
   ---@return TaskRunner.config
   H.get_config = function(config) ---@diagnostic disable-line redefined-local
      return vim.tbl_deep_extend(
         'force',
         TaskRunner.config,
         vim.b.taskrunner_config or {},
         config or {}
      )
   end
end

---@param input string
function H.parse(input)
   local fragments = vim.split(input, ' ', { plain = true, trimempty = true })
   local module_name, task_name = fragments[1], fragments[2]
   local modules = TaskRunner.get_modules()
   local module = modules[module_name] or nil
   return {
      __modules = modules,
      __fragments = fragments,
      __module_name = module_name,
      __task_name = task_name,
      ---@type string[]
      modules = vim.tbl_keys(modules),
      ---@type TaskRunner.Module?
      module = module,
      ---@type string[]?
      tasks = module ~= nil and vim.tbl_keys(module.tasks) or nil,
      ---@type TaskRunner.Task?
      task = module ~= nil and module.tasks[task_name] or nil,
   }
end

function H.search_providers()
   local config = H.get_config()
   local found = false
   local available_providers = {}
   for provider, module in pairs(H.provider_modules) do
      local ok = pcall(require, module)
      if ok then
         available_providers[provider] = 'task-runner.providers.' .. provider
         found = found or config.options.provider == provider
      end
   end

   if found then
      H.picker = available_providers[config.options.provider]
   else
      if vim.tbl_count(available_providers) == 0 then
         H.log(
            'No available providers found! Please install one of the following: '
               .. vim.inspect(H.priority),
            vim.log.levels.ERROR
         )
      else
         ---@type string[]
         local providers = vim.tbl_filter(function(str)
            return str ~= config.options.provider
               and available_providers[str] ~= nil
         end, H.priority)
         H.log(
            config.options.provider
               .. ' provider is not available. Falling back to '
               .. providers[1],
            vim.log.levels.WARN,
            { ttl = 6000, title = 'Task Picker' }
         )
         H.picker = available_providers[providers[1]]
      end
   end
end

---@alias TaskRunner.log fun(msg: string, level: vim.log.levels, opts?: Options)
---
---@type TaskRunner.log
function H.log(msg, level, opts)
   local notif = H.get_config().notification
   opts = vim.tbl_extend(
      'force',
      { title = notif.title, group = notif.group },
      opts
   )
   vim.notify(msg, level, opts)
end

---@type TaskRunner.log
H.schedule_log = vim.schedule_wrap(H.log)

function H.error(msg)
   error('(task-runner.nvim) ' .. msg)
end

---@param name string Name of the variable
---@param val any Value to check
---@param ref any Reference type string or object
---@param allow_nil boolean? Allow nil values
function H.check_type(name, val, ref, allow_nil)
   if
      type(val) == ref
      or (ref == 'callable' and vim.is_callable(val))
      or (allow_nil and val == nil)
   then
      return
   end
   H.error(string.format('`%s` should be %s, not %s', name, ref, type(val)))
end

-- =============================================================================
-- Module class
-- =============================================================================

---@class TaskRunner.ModuleConfig
---@field name? string Defaults to the filename
---@field cond? fun(self: TaskRunner.Module): boolean
---@field tasks table<string, any>

---@class TaskRunner.Module: TaskRunner.ModuleConfig
---@field private path string
---@field private hash string
---@field tasks table<string, TaskRunner.Task>
---@field is_valid boolean
H.Module = {}

---@param path string
---@param file TaskRunner.ModuleConfig
---@param opts? TaskRunner.Module
---@return TaskRunner.Module
function H.Module:new(path, file, opts)
   opts = vim.tbl_deep_extend('force', {
      name = file.name,
      tasks = {},
      cond = type(file.cond) == 'function' and file.cond or function()
         return true
      end,
   }, opts or {})

   opts.path = path
   opts.hash = vim.fn.sha256(vim.inspect(file))
   for name, task in pairs(file.tasks) do
      opts.tasks[name] = H.Task:new(name, task)
   end

   setmetatable(opts, self)
   self.__index = self
   return opts
end

---@return boolean # true if the module's hash is different
function H.Module:check_hash()
   local is_success, file = pcall(dofile, self.path)
   local hash = nil
   if is_success then
      hash = vim.fn.sha256(vim.inspect(file))
   end
   return hash ~= self.hash and is_success
end

function H.Module:get_path()
   return self.path
end

function H.Module:__tostring()
   return self.name
end

---@param path string
---@param file TaskRunner.ModuleConfig
function H.Module.assert(path, file)
   local name = file.name or vim.fn.fnamemodify(path, ':t')
   H.check_type('Module ' .. name, file, 'table')
   H.check_type(name .. '.name', file.name, 'string')
   H.check_type(name .. 'cond', file.cond, 'callable', true)
   H.check_type(name .. '.tasks', file.tasks, 'table')
   for task_name, task in pairs(file.tasks) do
      H.Task.assert(task_name, task)
   end
end

-- =============================================================================
-- Task Class
-- =============================================================================

---@class TaskRunner.Task
---@field name? string
---@field command string[] Command to run
---@field cond? fun(self: TaskRunner.Task): boolean
---@field cwd? string Working directory for job
---@field env? table<string, string>|string[] Environment looking like: { ['VAR'] = 'VALUE' } or { 'VAR=VALUE' }
---@field on_stdout? fun(error: string, data: string)

---@class TaskRunner.Task
H.Task = {}

---@param name string
---@param opts TaskRunner.Task
function H.Task:new(name, opts)
   opts = vim.tbl_deep_extend('force', {
      name = name,
      command = {},
      cwd = vim.loop.cwd(),
      env = {},
      on_stdout = function(_, data)
         H.log(
            data,
            vim.log.levels.INFO,
            { title = opts.name, annote = opts.name }
         )
      end,
      cond = function()
         return true
      end,
   }, opts or {})

   setmetatable(opts, self)
   self.__index = self
   return opts
end

function H.Task:run()
   if not self:cond() then
      return
   end
   local notify_opts = {
      title = self.name,
      annote = self.name,
      key = self.name .. 'Job',
   }
   H.log('Started...', vim.log.levels.INFO, notify_opts)
   local job = vim.system(self.command, {
      cwd = self.cwd,
      env = self.env,
      stdout = self.on_stdout,
   }, function(out)
      if out.code == 0 then
         H.schedule_log('Finished', vim.log.levels.INFO, notify_opts)
      else
         H.schedule_log(
            'Failed: ' .. out.stderr .. (out.stdout or ''),
            vim.log.levels.ERROR,
            notify_opts
         )
      end
   end)
end

function H.Task:__tostring()
   return self.name
end

---@param name string
---@param task TaskRunner.Task
function H.Task.assert(name, task)
   H.check_type(name .. '.command', task.command, 'table')
   H.check_type(name .. '.cwd', task.cwd, 'string', true)
   H.check_type(name .. '.env', task.env, 'table', true)
   H.check_type(name .. '.on_stdout', task.on_stdout, 'callable', true)
   H.check_type(name .. '.cond', task.cond, 'callable', true)
end

return TaskRunner
