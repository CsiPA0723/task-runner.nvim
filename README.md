# Task-Runner.nvim
<!-- markdownlint-disable MD033 -->

<a href="https://dotfyle.com/plugins/CsiPA0723/taskrunner.nvim"><img alt="used in configs" src="https://dotfyle.com/plugins/CsiPA0723/taskrunner.nvim/shield?style=for-the-badge" /></a> <!-- markdownlint-disable-line MD013 -->

## Setup

### Lazy.nvim

```lua
{
  'CsiPA0723/task-runner.nvim',
  dependencies = { 
    'nvim-lua/plenary.nvim',
    -- Avaiable providers --
    'folke/snacks.nvim', -- (Default)
    -- 'nvim-telescope/telescope.nvim',
    -- 'ibhagwan/fzf-lua',
  },
  event = 'VeryLazy',
  ---@type TaskRunner.config
  opts = {},
}
```

## Acknowledgements

- Lots of inspirations from [miroshQa/rittli.nvim](https://github.com/miroshQa/rittli.nvim)
- User command handling from [folke/trouble.nvim](https://github.com/folke/trouble.nvim)
- Picker provider handling from [2KAbhishek/pickme.nvim](https://github.com/2KAbhishek/pickme.nvim)

## License

This plugin is licensed under the MIT License.
See the [LICENSE](./LICENSE) file for more details.
