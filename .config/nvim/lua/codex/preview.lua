-- ~/.config/nvim/lua/codex/preview.lua
local M = {}

local function open_scratch(lines, filetype, title)
	title = title or "Codex Output"

	local bufname = "codex://" .. title
	local bufnr = vim.fn.bufnr(bufname)

	if bufnr == -1 then
		vim.cmd("botright new")
		bufnr = vim.api.nvim_get_current_buf()
		vim.api.nvim_buf_set_name(bufnr, bufname)
	else
		vim.cmd("botright sbuffer " .. bufnr)
	end

	vim.bo[bufnr].modifiable = true
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines or {})
	vim.bo[bufnr].buftype = "nofile"
	vim.bo[bufnr].bufhidden = "wipe"
	vim.bo[bufnr].swapfile = false

	if filetype then
		vim.bo[bufnr].filetype = filetype
	end

	vim.bo[bufnr].modifiable = false

	return bufnr
end

function M.open_diff(diff_lines, opts)
	opts = opts or {}

	local title = opts.title or "Codex Safe Diff Preview"
	local on_confirm = opts.on_confirm
	local on_abort = opts.on_abort

	local bufnr = open_scratch(diff_lines or {}, "diff", title)
	local confirmed = false

	vim.bo[bufnr].modifiable = false

	vim.keymap.set("n", "<leader>ca", function()
		local ok = true
		confirmed = true

		if on_confirm then
			ok = on_confirm()
		end

		if ok == false then
			confirmed = false
			return
		end

		if vim.api.nvim_buf_is_valid(bufnr) then
			vim.api.nvim_buf_delete(bufnr, { force = true })
		end
	end, {
		buffer = bufnr,
		silent = true,
		noremap = true,
		desc = "Codex: confirm preview apply",
	})

	vim.keymap.set("n", "q", function()
		if not confirmed and on_abort then
			on_abort()
		end

		if vim.api.nvim_buf_is_valid(bufnr) then
			vim.api.nvim_buf_delete(bufnr, { force = true })
		end
	end, {
		buffer = bufnr,
		silent = true,
		noremap = true,
		desc = "Close preview",
	})

	vim.notify("Diff ready. Press <leader>ca to validate and apply.", vim.log.levels.INFO, {
		title = "Codex",
	})

	return bufnr
end

return M