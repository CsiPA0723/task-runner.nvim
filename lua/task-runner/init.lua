local TaskRunner = {}
local H = {
   ---@alias path string
   ---Keys are the path to the module file
   ---@type table<path, TaskRunner.Module>
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
   ---@type table<integer, uv.uv_process_t>
   jobs = {},
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

   H.setup_modules()

   vim.api.nvim_create_user_command('Tasks', function(input)
      H.execute(input)
   end, {
      nargs = '*',
      complete = function(...)
         return H.complete(...)
      end,
      desc = 'Tasks',
   })

   local group = vim.api.nvim_create_augroup('TaskRunner', { clear = true })
   vim.api.nvim_create_autocmd('VimLeave', {
      group = group,
      callback = function()
         for _, handle in pairs(H.jobs) do
            H.close_handle(handle)
         end
      end,
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

---@param path string
function TaskRunner.load_module(path)
   local config = H.get_config()
   ---@type boolean, TaskRunner.Module
   local is_success, file = pcall(dofile, path)
   if not is_success then
      local name = vim.fn.fnamemodify(path, ':t')
      H.log(
         'Failed to load module: ' .. file,
         vim.log.levels.ERROR,
         { key = config.notification.keys.module_reload .. name }
      )
   else
      H.Module.assert(path, file)
      local module = H.Module:new(path, file)
      H.modules[module:get_path()] = module
   end
end

---Keys are the path to the module file
---@return table<path, TaskRunner.Module>
function TaskRunner.get_modules()
   H.check_modules()
   return H.modules
end

---@param name string
---@return TaskRunner.Module?
function TaskRunner.get_module(name)
   local modules = TaskRunner.get_modules()
   for _, module in pairs(modules) do
      if module.name == name then
         return module
      end
   end
   return nil
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
---@return TaskRunner.config
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

---@param input vim.api.keyset.create_user_command.command_args
function H.execute(input)
   H.check_modules()
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
function H.complete(prefix, line, col)
   line = line:sub(1, col):match('Tasks%s*(.*)$')
   local ret = H.parse(line)
   local candidates = {} ---@type string[]
   if ret.module == nil then
      ---@param module TaskRunner.Module
      local modules = vim.tbl_values(vim.tbl_map(function(module)
         return module.name
      end, TaskRunner.get_modules()))
      candidates = vim.list_extend(candidates, modules or {})
   else
      local tasks = vim.tbl_keys(ret.module.tasks)
      candidates = vim.list_extend(candidates, tasks or {})
   end
   candidates = vim.tbl_filter(function(x)
      return tostring(x):find(prefix, 1, true) == 1
   end, candidates)
   table.sort(candidates)
   return candidates
end

function H.setup_modules()
   H.modules = {}
   local config = H.get_config()

   H.log(
      'Loading modules...',
      vim.log.levels.INFO,
      { key = config.notification.keys.module_loading }
   )

   local files = vim.fn.glob(config.options.tasks_dir .. '/*.lua', false, true)

   if #files > 0 then
      for _, path in ipairs(files) do
         TaskRunner.load_module(path)
      end
      H.log(
         'Loaded modules!',
         vim.log.levels.INFO,
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

function H.check_modules()
   local key = H.get_config().notification.keys.module_reload
   local dir_stat, err = vim.uv.fs_stat(TaskRunner.config.options.tasks_dir)
   if dir_stat ~= nil and dir_stat.type == 'directory' then
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
   else
      H.log(err or 'Directory not accessable!', vim.log.levels.ERROR)
   end
end

-- TODO: Revise funciton with vim.pos and vim.range
-- NOTE: vim.pos and vim.range are experimental
---@param path string
---@param file TaskRunner.ModuleConfig
---@return { [string]: TaskRunner.position }
function H.get_positions(path, file)
   local positions = {} ---@type { [string]: TaskRunner.position }
   local tasks = vim.tbl_keys(file.tasks)
   for i, line in ipairs(vim.fn.readfile(path)) do
      for j, task in ipairs(tasks) do
         if string.match(line, '%s' .. task .. ' = {') then
            positions[task] = { i, 1 }
            table.remove(tasks, j)
         end
      end
   end
   return positions
end

---@alias TaskRunner.parse_output { __module_name: string, __task_name: string, module: TaskRunner.Module|nil, task: TaskRunner.Task|nil }

---@param input string
---@return TaskRunner.parse_output
function H.parse(input)
   local fragments = vim.split(input, ' ', { plain = true, trimempty = true })
   local module_name, task_name = fragments[1], fragments[2]
   local module = TaskRunner.get_module(module_name)
   local task = module ~= nil
         and not vim.tbl_isempty(module.tasks)
         and module.tasks[task_name]
      or nil
   return {
      __module_name = module_name,
      __task_name = task_name,
      module = module,
      task = task,
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

---@param handle uv.uv_pipe_t|uv.uv_process_t
function H.close_handle(handle)
   if handle and not handle:is_closing() then
      local type = handle:get_type()
      if type == 'process' then
         H.jobs[handle:get_pid()] = nil
      end
      handle:close()
   end
end

-- =============================================================================
-- Module class
-- =============================================================================

---@class TaskRunner.ModuleConfig
---@field name? string Defaults to the filename
---@field cond? fun(self: TaskRunner.Module): boolean
---@field tasks table<string, TaskRunner.TaskConfig>

---@class TaskRunner.Module: TaskRunner.ModuleConfig
---@field private _path string
---@field private _hash string
---@field tasks table<string, TaskRunner.Task>
---@field is_valid boolean
H.Module = {}

---@alias TaskRunner.position { [1]: number, [2]: number }

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

   local positions = H.get_positions(path, file)
   opts._path = path
   opts._hash = vim.fn.sha256(vim.fn.readblob(path))
   for name, task in pairs(file.tasks) do
      opts.tasks[name] = H.Task:new(name, positions[name], task)
   end

   setmetatable(opts, self)
   self.__index = self
   return opts
end

---@param task_name string
---@return TaskRunner.position
function H.Module:get_position(task_name)
   local task = self.tasks[task_name]
   return task == nil and { 0, 0 } or task.pos
end

---@return boolean # true if the module's hash is different
function H.Module:check_hash()
   local is_success = pcall(dofile, self._path)
   local hash = nil
   if is_success then
      hash = vim.fn.sha256(vim.fn.readblob(self._path))
   end
   return hash ~= self._hash and is_success
end

function H.Module:get_path()
   return self._path
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

---@class TaskRunner.TaskConfig
---@field name? string
---@field command string Command to run
---@field args? string[] Command to run
---@field cond? fun(self: TaskRunner.Task): boolean
---If true, spawn the child process in a detached state -
---this will make it a process group leader, and will effectively enable the
---child to keep running after the parent exits. Note that the child process
---will still keep the parent's event loop alive unless the parent process calls
---`uv.unref()` on the child's process handle.
---@field detached? boolean
---@field cwd? string Working directory for job
---@field env? table<string, string> Environment looking like: { ['VAR'] = 'VALUE' }
---@field on_stdout? fun(data: string)
---@field on_stderr? fun(error: string)
---@field timeout? integer Run the command with a time limit in ms.

---@class TaskRunner.Task : TaskRunner.TaskConfig
---@field pos { [1]: number, [2]: number }
H.Task = {}

---@param name string
---@param pos TaskRunner.position
---@param opts TaskRunner.TaskConfig
---@return TaskRunner.Task
function H.Task:new(name, pos, opts)
   opts = vim.tbl_deep_extend('force', {
      name = name,
      command = 'echo',
      args = { 'Testing' },
      cwd = vim.loop.cwd(),
      env = {},
      pos = pos,
      detached = false,
      on_stdout = function(data)
         H.log(
            data,
            vim.log.levels.INFO,
            { title = opts.name, annote = opts.name }
         )
      end,
      on_stderr = function(err)
         H.log(
            (err or 'Error'),
            vim.log.levels.ERROR,
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

   local uv = vim.uv
   local notify_opts = {
      title = self.name,
      annote = self.name,
   }

   local ok, is_exe = pcall(vim.fn.executable, self.command)
   if not ok and 1 ~= is_exe then
      H.log(
         'Command not found: ' .. self.command,
         vim.log.levels.ERROR,
         notify_opts
      )
      return
   end

   local notify_opts_with_key =
      vim.tbl_extend('force', notify_opts, { key = self.name .. 'Job' })
   H.log('Started...', vim.log.levels.INFO, notify_opts_with_key)

   local stdout = uv.new_pipe()
   local stderr = uv.new_pipe()
   local stdio = { nil, stdout, stderr }
   if not (stdout and stderr) then
      H.error('Failed to create stdio')
      return
   end

   ---@param err nil|string
   ---@param chunk string|nil
   local handle_stdout = vim.schedule_wrap(function(err, chunk)
      if err then
         H.log('stdout error:' .. err, vim.log.levels.ERROR, notify_opts)
      elseif chunk then
         self.on_stdout(chunk)
      else
         H.log('Disconected stdout', vim.log.levels.DEBUG, notify_opts)
      end
   end)

   ---@param err nil|string
   ---@param chunk string|nil
   local handle_stderr = vim.schedule_wrap(function(err, chunk)
      if err then
         H.log('stderr error:' .. err, vim.log.levels.ERROR, notify_opts)
      elseif chunk then
         self.on_stderr(chunk)
      else
         H.log('Disconected stderr', vim.log.levels.DEBUG, notify_opts)
      end
   end)

   local handle, pid
   ---@diagnostic disable-next-line missing-fields
   handle, pid = uv.spawn(self.command, {
      args = self.args,
      cwd = self.cwd,
      env = self.env,
      detached = self.detached,
      stdio = stdio,
   }, function(code, signal)
      if code == 0 then
         H.schedule_log('Finished', vim.log.levels.INFO, notify_opts_with_key)
      else
         H.schedule_log('Error', vim.log.levels.ERROR, notify_opts_with_key)
      end
      H.schedule_log('Signal: ' .. signal, vim.log.levels.DEBUG, notify_opts)
      stdout:read_stop()
      stderr:read_stop()
      H.close_handle(stdout)
      H.close_handle(stderr)
      H.close_handle(handle)
   end)

   H.jobs[pid] = handle
   H.log('process opened: ' .. pid, vim.log.levels.DEBUG, notify_opts)

   uv.read_start(stdout, handle_stdout)
   uv.read_start(stderr, handle_stderr)

   if type(self.timeout) == 'number' then
      vim.fn.timer_start(self.timeout, function()
         stdout:read_stop()
         stderr:read_stop()
         H.close_handle(stdout)
         H.close_handle(stderr)
         H.close_handle(handle)
         H.schedule_log('Timeout', vim.log.levels.ERROR, notify_opts_with_key)
      end)
   end

   uv.run()
end

function H.Task:__tostring()
   return self.name
end

---@param name string
---@param task TaskRunner.TaskConfig
function H.Task.assert(name, task)
   H.check_type(name .. '.command', task.command, 'string')
   H.check_type(name .. '.args', task.args, 'table', true)
   H.check_type(name .. '.cwd', task.cwd, 'string', true)
   H.check_type(name .. '.env', task.env, 'table', true)
   H.check_type(name .. '.on_stdout', task.on_stdout, 'callable', true)
   H.check_type(name .. '.cond', task.cond, 'callable', true)
end

return TaskRunner
