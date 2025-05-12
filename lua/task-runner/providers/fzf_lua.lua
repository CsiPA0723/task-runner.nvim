local M = {}
function M.pick(opts)
	local formatted_items = {}
	local item_map = {}
	for _, item in ipairs(opts.items) do
		local entry = opts.entry_maker(item)
		table.insert(formatted_items, entry.display)
		item_map[entry.display] = item
	end

	local CustomPreviewer = require('fzf-lua.previewer.builtin').base:extend()
	function CustomPreviewer:new(o, preview_opts, fzf_win)
		CustomPreviewer.super.new(self, o, preview_opts, fzf_win)
		setmetatable(self, CustomPreviewer)
		self.item_map = item_map
		return self
	end

	function CustomPreviewer:populate_preview_buf(entry_str)
		local bufnr = self:get_tmp_buffer()
		local item = self.item_map[entry_str]
		local preview_text = opts.preview_generator(item)
		local lines = vim.split(preview_text, '\n')
		vim.bo[bufnr].filetype = opts.preview_ft or 'markdown'
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

		self:set_preview_buf(bufnr)
		if self.win and type(self.win.update_scrollbar) == 'function' then
			self.win:update_scrollbar()
		end
	end

	require('fzf-lua').fzf_exec(formatted_items, {
		prompt = opts.title,
		previewer = CustomPreviewer,
		actions = {
			['default'] = function(selected)
				if selected and #selected > 0 then
					local item = item_map[selected[1]]
					if item then
						opts.selection_handler(nil, { value = item })
					end
				end
			end,
		},
	})
end
return M
