local M = {}
function M.pick(opts)
	require('telescope.pickers')
		.new({}, {
			prompt_title = opts.title,
			finder = require('telescope.finders').new_table({
				results = opts.items,
				entry_maker = opts.entry_maker,
			}),
			sorter = require('telescope.sorters').get_generic_fuzzy_sorter(),
			previewer = require('telescope.previewers').new_buffer_previewer({
				define_preview = function(self, entry, _)
					local repo_info = opts.preview_generator(entry.value)
					vim.bo[self.state.bufnr].filetype = opts.preview_ft or 'markdown'
					vim.api.nvim_buf_set_lines(
						self.state.bufnr,
						0,
						-1,
						false,
						vim.split(repo_info, '\n')
					)
				end,
			}),
			attach_mappings = function(prompt_bufnr, _)
				require('telescope.actions').select_default:replace(function()
					local selection =
						require('telescope.actions.state').get_selected_entry()
					require('telescope.actions').close(prompt_bufnr)
					opts.selection_handler(prompt_bufnr, selection)
				end)
				return true
			end,
		})
		:find()
end
return M
