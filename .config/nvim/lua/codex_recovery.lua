local M = {}

local last_failure = nil

local function now_string()
	return os.date("%Y-%m-%d %H:%M:%S")
end

local function copy(tbl)
	return vim.deepcopy(tbl)
end

local function open_scratch(lines, title, filetype)
	title = title or "Codex Failure"
	filetype = filetype or "text"

	local bufname = "codex://" .. title
	local bufnr = vim.fn.bufnr(bufname)

	if bufnr == -1 then
		vim.cmd("botright new")
		bufnr = vim.api.nvim_get_current_buf()
		vim.api.nvim_buf_set_name(bufnr, bufname)
	else
		vim.cmd("botright sbuffer " .. bufnr)
	end

	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines or {})
	vim.bo[bufnr].buftype = "nofile"
	vim.bo[bufnr].bufhidden = "wipe"
	vim.bo[bufnr].swapfile = false
	vim.bo[bufnr].filetype = filetype

	return bufnr
end

function M.capture(opts)
	opts = opts or {}

	last_failure = {
		kind = opts.kind or "unknown_failure",
		op = opts.op,
		mode = opts.mode,
		file = opts.file,
		reason = opts.reason or "codex_failure",
		title = opts.title or "Codex Failure",
		lines = opts.lines or { "No diagnostic output available." },
		updated_at = now_string(),
	}

	return copy(last_failure)
end

function M.get_last_failure()
	if not last_failure then
		return nil
	end
	return copy(last_failure)
end

function M.clear_last_failure()
	last_failure = nil
end

function M.render_last_failure_lines()
	local f = M.get_last_failure()

	if not f then
		return {
			"Codex Recovery Report",
			"=====================",
			"",
			"No failure has been captured in this session.",
		}
	end

	local lines = {
		"Codex Recovery Report",
		"=====================",
		"",
		"Failure kind: " .. tostring(f.kind or "-"),
		"Operation:    " .. tostring(f.op or "-"),
		"Mode:         " .. tostring(f.mode or "-"),
		"File:         " .. tostring(f.file or "-"),
		"Updated at:   " .. tostring(f.updated_at or "-"),
		"",
		"Reason:",
		tostring(f.reason or "-"),
		"",
		"Captured output:",
	}

	local payload = f.lines or { "No diagnostic output available." }
	for _, line in ipairs(payload) do
		lines[#lines + 1] = line
	end

	return lines
end

function M.show_last_failure()
	open_scratch(M.render_last_failure_lines(), "Recovery", "markdown")
end

function M.show_failure(opts)
	opts = opts or {}

	local reason = opts.reason or "codex_failure"
	local title = opts.title or "Codex Failure"
	local lines = opts.lines or { "No diagnostic output available." }

	M.capture(opts)

	vim.notify(reason, vim.log.levels.ERROR, { title = "Codex" })
	open_scratch(lines, title, "text")
end

return M