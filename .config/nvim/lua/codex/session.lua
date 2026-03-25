local M = {}

local memory = require("codex_memory")

local function format_timestamp(ts)
	if not ts then
		return "-"
	end

	local n = tonumber(ts)
	if not n then
		return tostring(ts)
	end

	return os.date("%Y-%m-%d %H:%M:%S", n)
end

local function open_report_buffer(lines)
	local bufname = "codex://last-op"
	local bufnr = vim.fn.bufnr(bufname)

	if bufnr == -1 then
		vim.cmd("botright new")
		bufnr = vim.api.nvim_get_current_buf()
		vim.api.nvim_buf_set_name(bufnr, bufname)
	else
		vim.cmd("botright sbuffer " .. bufnr)
	end

	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
	vim.bo[bufnr].buftype = "nofile"
	vim.bo[bufnr].bufhidden = "wipe"
	vim.bo[bufnr].swapfile = false
	vim.bo[bufnr].filetype = "markdown"

	return bufnr
end

function M.read_last_op()
	return memory.get_last_op()
end

function M.render_last_op_lines()
	local last = M.read_last_op()

	if not last then
		return {
			"Codex Last Operation",
			"====================",
			"",
			"No operation has been captured in this session.",
		}
	end

	return {
		"Codex Last Operation",
		"====================",
		"",
		"Operation:      " .. tostring(last.op or "-"),
		"Mode:           " .. tostring(last.mode or "-"),
		"Prompt version: " .. tostring(last.prompt_version or "-"),
		"Timestamp:      " .. format_timestamp(last.timestamp),
		"",
		"Prompt:",
		tostring(last.prompt or "-"),
	}
end

function M.show_last_op()
	open_report_buffer(M.render_last_op_lines())
end

function M.repeat_last_op()
	local last = M.read_last_op()

	if not last then
		vim.notify("No last Codex operation captured", vim.log.levels.WARN, { title = "Codex" })
		return
	end

	if not last.prompt or vim.trim(last.prompt) == "" then
		vim.notify("Last Codex operation has no reusable prompt", vim.log.levels.WARN, { title = "Codex" })
		return
	end

	require("codex_cli").open_scratchpad_with_text(last.prompt)
end

return M
