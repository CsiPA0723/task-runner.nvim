local M = {}
function M.pick(opts)
	require('snacks.picker').pick({
		items = vim.tbl_map(function(item)
			return {
				text = opts.entry_maker(item).display,
				value = item,
				preview = {
					text = opts.preview_generator(item),
					ft = opts.preview_ft or 'markdown',
				},
			}
		end, opts.items),
		title = opts.title,
		format = Snacks.picker.format.text,
		preview = 'preview',
		actions = {
			confirm = function(_, selected)
				if selected and selected.value then
					vim.cmd('close')
					opts.selection_handler(nil, { value = selected.value })
				end
			end,
		},
	})
end

return M
