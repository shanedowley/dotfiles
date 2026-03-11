local M = {}

local function open_scratch(lines, title)
	vim.cmd("botright new")
	local buf = vim.api.nvim_get_current_buf()

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines or {})
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].swapfile = false
	vim.bo[buf].filetype = "text"

	if title then
		vim.api.nvim_buf_set_name(buf, "codex://" .. title)
	end
end

function M.show_failure(opts)
	local reason = opts.reason or "codex_failure"
	local title = opts.title or "Codex Failure"
	local lines = opts.lines or { "No diagnostic output available." }

	vim.notify(reason, vim.log.levels.ERROR, { title = "Codex" })

	open_scratch(lines, title)
end

return M
