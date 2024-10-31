# Task-Runner.nvim

## Setup

### Lazy.nvim

```lua
{
  'CsiPA0723/task-runner.nvim',
    dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-telescope/telescope.nvim',
    'j-hui/fidget.nvim',
  },
  lazy = true,
  cmd = { 'Tasks' },
  opts = {},
}
```

## Acknowledgements

Lots of inspirations from [miroshQa/rittli.nvim](https://github.com/miroshQa/rittli.nvim)

## License

This plugin is licensed under the MIT License.
See the [LICENSE](./LICENSE) file for more details.
