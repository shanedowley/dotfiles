local M = {}

local state = {
	status = "idle",
	op = nil,
	mode = nil,
	file = nil,
	message = nil,
	updated_at = os.date("%Y-%m-%d %H:%M:%S"),
}

local allowed = {
	idle = true,
	running = true,
	preview = true,
	validating = true,
	applied = true,
	failed = true,
}

local function now_string()
	return os.date("%Y-%m-%d %H:%M:%S")
end

local function copy(tbl)
	return vim.deepcopy(tbl)
end

function M.set(status, opts)
	opts = opts or {}

	if not allowed[status] then
		error("codex.state.set: invalid status: " .. tostring(status))
	end

	state.status = status
	state.op = opts.op or state.op
	state.mode = opts.mode or state.mode
	state.file = opts.file or state.file
	state.message = opts.message
	state.updated_at = now_string()

	return copy(state)
end

function M.get()
	return copy(state)
end

function M.reset()
	state = {
		status = "idle",
		op = nil,
		mode = nil,
		file = nil,
		message = nil,
		updated_at = now_string(),
	}

	return copy(state)
end

function M.render_lines()
	local s = M.get()

	return {
		"Codex Workflow State",
		"====================",
		"",
		"Status:     " .. tostring(s.status or "nil"),
		"Operation:  " .. tostring(s.op or "-"),
		"Mode:       " .. tostring(s.mode or "-"),
		"File:       " .. tostring(s.file or "-"),
		"Message:    " .. tostring(s.message or "-"),
		"Updated at: " .. tostring(s.updated_at or "-"),
	}
end

local function open_report_buffer(lines)
	local bufname = "codex://state"
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

function M.show()
	open_report_buffer(M.render_lines())
end

return M

