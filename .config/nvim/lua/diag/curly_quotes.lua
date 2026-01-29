local api = vim.api

local M = {}

-- Characters we want to detect
local bad_chars = {
	"“",
	"”",
	"‘",
	"’",
}

-- Highlight group
api.nvim_set_hl(0, "CurlyQuoteError", { fg = "#ff5555", bold = true })

local function highlight_curly_quotes(bufnr)
	bufnr = bufnr or api.nvim_get_current_buf()
	api.nvim_buf_clear_namespace(bufnr, -1, 0, -1)

	local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
	for ln, text in ipairs(lines) do
		for _, chr in ipairs(bad_chars) do
			local from = 1
			while true do
				local s, e = text:find(chr, from, true)
				if not s then
					break
				end
				api.nvim_buf_add_highlight(bufnr, -1, "CurlyQuoteError", ln - 1, s - 1, e)
				from = e + 1
			end
		end
	end
end

-- Expose functionality
function M.attach(bufnr)
	highlight_curly_quotes(bufnr)
end

return M
