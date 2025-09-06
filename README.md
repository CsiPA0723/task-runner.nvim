# Task-Runner.nvim
<!-- markdownlint-disable MD033 -->

<a href="https://dotfyle.com/plugins/CsiPA0723/task-runner.nvim"><img alt="used in config" src="https://dotfyle.com/plugins/CsiPA0723/task-runner.nvim/shield?style=for-the-badge" /></a><!-- markdownlint-disable-line MD013 -->

## Setup

### Lazy.nvim

```lua
{
  'CsiPA0723/task-runner.nvim',
  dependencies = { 
    -- Available providers --
    'folke/snacks.nvim', -- (Default)
    -- 'nvim-telescope/telescope.nvim',
    -- 'ibhagwan/fzf-lua',
    -- 'nvim-mini/mini.pick',
  },
  cmd = 'Tasks'
  ---@module 'TaskRunner'
  ---@type TaskRunner.config
  opts = {},
}
```

## Progress

- [x] Command framework
- [x] Picker framework
- [ ] Picker providers implemented
  - [x] snacks
  - [ ] telescope [Issue: #1](https://github.com/CsiPA0723/task-runner.nvim/issues/1)
  - [ ] fzf-lua [Issue: #2](https://github.com/CsiPA0723/task-runner.nvim/issues/2)
  - [ ] mini.pick [Issue: #3](https://github.com/CsiPA0723/task-runner.nvim/issues/3)
- [ ] Local folder tasks
- [ ] VSCode tasks integration

## Acknowledgements

- Inspiration from [miroshQa/rittli.nvim](https://github.com/miroshQa/rittli.nvim)
- User command handling from [folke/trouble.nvim](https://github.com/folke/trouble.nvim)
- Picker provider handling from [2KAbhishek/pickme.nvim](https://github.com/2KAbhishek/pickme.nvim)

## License

This plugin is licensed under the MIT License.
See the [LICENSE](./LICENSE) file for more details.
