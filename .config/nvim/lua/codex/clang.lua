-- ~/.config/nvim/lua/codex/clang.lua
local M = {}

local mode = require("codex_mode")
local prompt = require("codex_prompt")

local uv = vim.uv or vim.loop

local function hrtime_ms()
	return math.floor((uv.hrtime() or 0) / 1e6)
end

local function system_run(argv)
	if not vim.system then
		return { code = 127, stdout = "", stderr = "vim.system not available", signal = nil }
	end

	local res = vim.system(argv, { text = true }):wait()
	return {
		code = res.code or 1,
		stdout = res.stdout or "",
		stderr = res.stderr or "",
		signal = res.signal,
	}
end

local function split_nonempty_lines(s)
	local out = {}
	for line in (s or ""):gmatch("([^\n]*)\n?") do
		if line ~= "" then
			table.insert(out, line)
		end
	end
	return out
end

local function with_line_numbers(lines, start_at)
	start_at = start_at or 1
	local out = {}
	for i, l in ipairs(lines or {}) do
		out[#out + 1] = string.format("%4d | %s", start_at + i - 1, l or "")
	end
	return out
end

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

	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines or {})
	vim.bo[bufnr].buftype = "nofile"
	vim.bo[bufnr].bufhidden = "wipe"
	vim.bo[bufnr].swapfile = false

	if filetype then
		vim.bo[bufnr].filetype = filetype
	end
end

function M.is_cc_ft(ft)
	return prompt.is_c_family and prompt.is_c_family(ft or "") == true
end

local function clang_exe_for_ft(ft)
	ft = ft or ""
	if ft == "c" then
		return "clang"
	end
	return "clang++"
end

local function clang_args_for_ft(ft)
	ft = ft or ""
	if ft == "c" then
		return { "-fsyntax-only", "-std=c17" }
	end
	return { "-fsyntax-only", "-std=c++20" }
end

function M.preflight_range_replace(bufnr, ft, start_line, end_line, replacement_lines)
	bufnr = bufnr or 0
	ft = ft or (vim.bo[bufnr].filetype or "")

	local meta = {
		argv = {},
		code = nil,
		signal = nil,
		elapsed_ms = nil,
	}

	local exe = clang_exe_for_ft(ft)
	if vim.fn.executable(exe) ~= 1 then
		meta.skipped = true
		meta.reason = exe .. " not found in PATH"
		return true, { "clang preflight skipped: " .. exe .. " not found in PATH" }, "", meta
	end

	if not vim.system then
		meta.skipped = true
		meta.reason = "vim.system not available"
		return true, { "clang preflight skipped: vim.system not available" }, "", meta
	end

	local orig = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local new_lines = {}

	local start0 = math.max(0, (start_line or 1) - 1)
	local end0_incl = math.max(start0, (end_line or start_line or 1) - 1)

	for i = 1, start0 do
		new_lines[#new_lines + 1] = orig[i]
	end
	for _, l in ipairs(replacement_lines or {}) do
		new_lines[#new_lines + 1] = l
	end
	for i = end0_incl + 2, #orig do
		new_lines[#new_lines + 1] = orig[i]
	end

	local tmpdir = vim.fn.tempname()
	pcall(vim.fn.mkdir, tmpdir, "p")

	local ext = (ft == "c") and ".c" or ".cpp"
	local tmppath = tmpdir .. "/0" .. ext
	vim.fn.writefile(new_lines, tmppath)

	local args = clang_args_for_ft(ft)
	local argv = vim.list_extend({ exe }, args)
	table.insert(argv, tmppath)

	meta.argv = argv

	local t0 = hrtime_ms()
	local res = system_run(argv)
	local t1 = hrtime_ms()

	meta.code = res.code
	meta.signal = res.signal
	meta.elapsed_ms = (t1 - t0)

	if res.code == 0 then
		return true, {}, tmppath, meta
	end

	local diag = split_nonempty_lines(res.stderr)
	if #diag == 0 then
		diag = split_nonempty_lines(res.stdout)
	end

	return false, diag, tmppath, meta
end

function M.open_rejection_scratch(opts)
	local title = opts.title or "Codex Rejected (clang)"
	local ft = opts.ft or ""
	local m = mode.current()

	local report = {}
	report[#report + 1] = "Codex clang validation REJECTED the change (buffer left untouched)."
	report[#report + 1] = ""
	report[#report + 1] = "Context:"
	report[#report + 1] = "  mode: " .. tostring(m)
	report[#report + 1] = "  filetype: " .. tostring(ft)
	if opts.start_line and opts.end_line then
		report[#report + 1] = string.format("  range: %d..%d", opts.start_line, opts.end_line)
	end
	if opts.temp_path and opts.temp_path ~= "" then
		report[#report + 1] = "  clang temp file: " .. opts.temp_path
	end

	local meta = opts.meta or {}
	if meta.argv and #meta.argv > 0 then
		report[#report + 1] = "  clang argv: " .. table.concat(meta.argv, " ")
	end
	if meta.code ~= nil then
		report[#report + 1] = "  exit code: " .. tostring(meta.code)
	end
	if meta.signal ~= nil then
		report[#report + 1] = "  signal: " .. tostring(meta.signal)
	end
	if meta.elapsed_ms ~= nil then
		report[#report + 1] = "  elapsed: " .. tostring(meta.elapsed_ms) .. "ms"
	end
	if meta.skipped then
		report[#report + 1] = "  (validation skipped: " .. tostring(meta.reason or "unknown") .. ")"
	end

	report[#report + 1] = ""
	report[#report + 1] = "Instruction:"
	report[#report + 1] = "  " .. tostring(opts.user_instruction or "")
	report[#report + 1] = ""
	report[#report + 1] = "=== Candidate replacement (with line numbers) ==="
	report[#report + 1] = ""

	local cand = opts.candidate_lines or {}
	for _, l in ipairs(with_line_numbers(cand, 1)) do
		report[#report + 1] = l
	end

	report[#report + 1] = ""
	report[#report + 1] = "=== clang output ==="
	report[#report + 1] = ""

	local clang_lines = opts.clang_lines or {}
	if #clang_lines == 0 then
		report[#report + 1] = "(no output)"
	else
		for _, l in ipairs(clang_lines) do
			report[#report + 1] = l
		end
	end

	open_scratch(report, "text", title)
end

return M

