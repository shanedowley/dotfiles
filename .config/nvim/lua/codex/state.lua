local M = {}

local state = {
	status = "idle",
	op = nil,
	mode = nil,
	file = nil,
	message = nil,
	updated_at = os.date("%Y-%m-%d %H:%M:%S"),
}

local history = {}
local max_history = 20

local allowed = {
	idle = true,
	running = true,
	preview = true,
	validating = true,
	applied = true,
	failed = true,
}

local status_icons = {
	idle = "○",
	running = "⚙",
	preview = "👁",
	validating = "🧪",
	applied = "✅",
	failed = "✖",
}

local function now_string()
	return os.date("%Y-%m-%d %H:%M:%S")
end

local function time_short()
	return os.date("%H:%M:%S")
end

local function copy(tbl)
	return vim.deepcopy(tbl)
end

local function basename(path)
	if not path or path == "" then
		return "-"
	end
	return vim.fn.fnamemodify(path, ":t")
end

local function status_with_icon(status)
	local icon = status_icons[status or ""] or "•"
	return string.format("%s %s", icon, tostring(status or "-"))
end

local function truncate(text, max_len)
	text = tostring(text or "-")
	if vim.fn.strdisplaywidth(text) <= max_len then
		return text
	end
	return vim.fn.strcharpart(text, 0, max_len - 1) .. "…"
end

local function push_history(snapshot)
	history[#history + 1] = copy(snapshot)
	if #history > max_history then
		table.remove(history, 1)
	end
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

	push_history({
		time = time_short(),
		status = state.status,
		op = state.op,
		mode = state.mode,
		file = state.file,
		message = state.message,
		updated_at = state.updated_at,
	})

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

	history = {}

	return copy(state)
end

function M.get_history()
	return copy(history)
end

function M.clear_history()
	history = {}
end

function M.render_lines()
	local s = M.get()

	return {
		"Codex Workflow State",
		"====================",
		"",
		("Status:     %s"):format(status_with_icon(s.status)),
		("Operation:  %s"):format(tostring(s.op or "-")),
		("Mode:       %s"):format(tostring(s.mode or "-")),
		("File:       %s"):format(tostring(s.file or "-")),
		("File name:  %s"):format(basename(s.file)),
		("Message:    %s"):format(tostring(s.message or "-")),
		("Updated at: %s"):format(tostring(s.updated_at or "-")),
	}
end

function M.render_history_lines()
	local items = M.get_history()

	local lines = {
		"Codex Workflow State History",
		"============================",
		"",
	}

	if #items == 0 then
		lines[#lines + 1] = "No state transitions captured in this session."
		return lines
	end

	lines[#lines + 1] = string.format(
		"%-10s %-14s %-34s %-10s %-16s %s",
		"Time",
		"Status",
		"Operation",
		"Mode",
		"File",
		"Message"
	)
	lines[#lines + 1] = string.rep("-", 120)

	for i = #items, 1, -1 do
		local item = items[i]
		lines[#lines + 1] = string.format(
			"%-10s %-14s %-34s %-10s %-16s %s",
			tostring(item.time or "-"),
			status_with_icon(item.status),
			truncate(item.op, 34),
			tostring(item.mode or "-"),
			truncate(basename(item.file), 16),
			tostring(item.message or "-")
		)
	end

	return lines
end

local function open_report_buffer(lines, bufname, filetype)
	bufname = bufname or "codex://state"
	filetype = filetype or "markdown"

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
	vim.bo[bufnr].filetype = filetype

	return bufnr
end

function M.show()
	open_report_buffer(M.render_lines(), "codex://state", "markdown")
end

function M.show_history()
	open_report_buffer(M.render_history_lines(), "codex://state-history", "text")
end

return M