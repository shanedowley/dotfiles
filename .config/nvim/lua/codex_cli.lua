-- ~/.config/nvim/lua/codex_cli.lua
local M = {}

local parse = require("codex_parse")
local prompt = require("codex_prompt")
local mode = require("codex_mode")
local codex_log = require("codex_log")

-- -------------------------------------------------------------------
-- Codex UI helpers (spinner)
-- -------------------------------------------------------------------

local uv = vim.uv or vim.loop

local spinner -- forward-declare so ui_start/ui_stop capture the SAME local

spinner = {
	timer = nil,
	idx = 1,
	notif = nil,
	active = false,
}

local frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }

local function ui_start(msg)
	-- Stop any previous spinner cleanly
	if spinner.timer then
		pcall(spinner.timer.stop, spinner.timer)
		pcall(spinner.timer.close, spinner.timer)
		spinner.timer = nil
	end

	spinner.active = true
	spinner.idx = 1

	local ok_notify, notify = pcall(require, "notify")
	if ok_notify then
		spinner.notif = notify(msg .. " " .. frames[spinner.idx], vim.log.levels.INFO, {
			title = "Codex",
			timeout = false,
		})
	else
		vim.api.nvim_echo({ { msg .. " " .. frames[spinner.idx], "ModeMsg" } }, false, {})
	end

	spinner.timer = uv.new_timer()
	spinner.timer:start(
		120,
		120,
		vim.schedule_wrap(function()
			if not spinner.active then
				return
			end
			spinner.idx = (spinner.idx % #frames) + 1
			local text = msg .. " " .. frames[spinner.idx]

			local ok2, notify2 = pcall(require, "notify")
			if ok2 then
				spinner.notif = notify2(text, vim.log.levels.INFO, {
					title = "Codex",
					timeout = false,
					replace = spinner.notif,
				})
			else
				vim.api.nvim_echo({ { text, "ModeMsg" } }, false, {})
			end
		end)
	)
end

local function ui_stop(msg, level)
	spinner.active = false
	if spinner.timer then
		spinner.timer:stop()
		spinner.timer:close()
		spinner.timer = nil
	end

	local ok_notify, notify = pcall(require, "notify")
	if ok_notify then
		notify(msg, level or vim.log.levels.INFO, {
			title = "Codex",
			timeout = 1500,
			replace = spinner.notif,
		})
	else
		vim.api.nvim_echo({ { msg, "ModeMsg" } }, false, {})
		vim.defer_fn(function()
			vim.api.nvim_echo({ { "" } }, false, {})
		end, 1200)
	end
end

-- -------------------------------------------------------------------
-- Helpers
-- -------------------------------------------------------------------

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

local function prompt_user(opts, cb)
	vim.ui.input({ prompt = opts.prompt, default = opts.default }, function(answer)
		if answer and answer ~= "" then
			cb(answer)
		end
	end)
end

local function collect_selection()
	local bufnr = 0

	-- Try visual anchors first (most reliable)
	local vpos = vim.fn.getpos("v")
	local cpos = vim.fn.getpos(".")

	local start_line = vpos[2]
	local start_col = vpos[3]
	local end_line = cpos[2]
	local end_col = cpos[3]

	if start_line > 0 and end_line > 0 then
		if start_line > end_line or (start_line == end_line and start_col > end_col) then
			start_line, end_line = end_line, start_line
			start_col, end_col = end_col, start_col
		end

		local lines = vim.api.nvim_buf_get_text(bufnr, start_line - 1, start_col - 1, end_line - 1, end_col, {})
		return table.concat(lines, "\n"), start_line, end_line
	end

	-- Fallback to '< and '> marks
	local start_pos = vim.fn.getpos("'<")
	local end_pos = vim.fn.getpos("'>")

	start_line = start_pos[2]
	end_line = end_pos[2]

	if start_line > 0 and end_line > 0 then
		if start_line > end_line then
			start_line, end_line = end_line, start_line
		end

		local lines = vim.fn.getline(start_line, end_line)
		return table.concat(lines, "\n"), start_line, end_line
	end

	return nil, nil, nil
end

-- -------------------------------------------------------------------
-- Tree-sitter helpers: get current function range (C/C++)
-- -------------------------------------------------------------------

local function ts_get_node_at_cursor()
	-- Neovim 0.10+: vim.treesitter
	if not vim.treesitter or not vim.treesitter.get_parser then
		return nil
	end

	local bufnr = 0
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	row = row - 1

	local ok_parser, parser = pcall(vim.treesitter.get_parser, bufnr)
	if not ok_parser or not parser then
		return nil
	end

	local trees = parser:parse()
	local tree = trees and trees[1]
	if not tree then
		return nil
	end

	local root = tree:root()
	if not root then
		return nil
	end

	-- named_descendant_for_range is usually best for cursor targeting
	local node = root:named_descendant_for_range(row, col, row, col)
	return node
end

local function ts_find_enclosing_function_node(node)
	-- C / C++ Tree-sitter node types commonly include:
	--   - function_definition
	--   - (sometimes) method_definition (depending on grammar/version)
	-- We'll accept either.
	local function_types = {
		function_definition = true,
		method_definition = true,
	}

	while node do
		local t = node:type()
		if function_types[t] then
			return node
		end
		node = node:parent()
	end
	return nil
end

local function ts_node_to_line_range(node)
	-- node:range() returns 0-based: start_row, start_col, end_row, end_col (end is exclusive)
	local sr, _, er, ec = node:range()

	local start_line = sr + 1

	-- If the node ends exactly at column 0 of the next line,
	-- we treat the previous line as the "last line" for whole-line replacement.
	local end_line
	if ec == 0 and er > sr then
		end_line = er
	else
		end_line = er + 1
	end

	return start_line, end_line
end

local function get_current_function_range_cc()
	local ft = vim.bo.filetype or ""
	if ft ~= "c" and ft ~= "cpp" and ft ~= "objc" and ft ~= "objcpp" then
		return nil, nil
	end

	local node = ts_get_node_at_cursor()
	if not node then
		return nil, nil
	end

	local fn_node = ts_find_enclosing_function_node(node)
	if not fn_node then
		return nil, nil
	end

	local start_line, end_line = ts_node_to_line_range(fn_node)
	return start_line, end_line
end

-- ✅ required by replace_range/replace_selection/apply_inline
local function lines_count(s)
	if not s or s == "" then
		return 0
	end
	local _, n = s:gsub("\n", "\n")
	return n + 1
end

-- ✅ required by replace_range/replace_selection/run_* paths
local function collapse_if_doubled(body, want_lines)
	if type(body) ~= "table" then
		return body
	end
	local n = #body
	if n == 0 then
		return body
	end

	-- common tiny case: one line duplicated -> two identical lines
	if want_lines == 1 and n == 2 and body[1] == body[2] then
		return { body[1] }
	end

	-- general case: output block repeated twice
	if want_lines and n == (2 * want_lines) and (n % 2 == 0) then
		local half = n / 2
		for i = 1, half do
			if body[i] ~= body[i + half] then
				return body
			end
		end
		local out = {}
		for i = 1, half do
			out[#out + 1] = body[i]
		end
		return out
	end

	-- if want_lines is unknown, only collapse obvious even-length full repetition
	if (not want_lines) and (n % 2 == 0) and n >= 2 then
		local half = n / 2
		for i = 1, half do
			if body[i] ~= body[i + half] then
				return body
			end
		end
		local out = {}
		for i = 1, half do
			out[#out + 1] = body[i]
		end
		return out
	end

	return body
end

-- Refactor-mode guard: candidate rewrite must remain exactly ONE function definition
-- and must match the original function name.

local function extract_first_function_name(text)
	for _, l in ipairs(vim.split(text or "", "\n", { plain = true })) do
		local line = vim.trim(l or "")
		if line ~= "" then
			-- Skip obvious non-signature starters
			if line:match("^%s*//") or line:match("^%s*/%*") or line:match("^%s*#") then
				goto continue
			end

			-- Match common C/C++ function definition starters.
			-- Examples:
			--   static int foo(int x)
			--   int foo(int x)
			--   inline int ns::foo(int x)
			--   constexpr auto foo(int x) -> int
			--
			-- This is intentionally heuristic (fast + robust enough for guarding).
			local _, name = line:match("^%s*(.-)%s+([%w_:~]+)%s*%b()%s*$")
			if name then
				return name
			end

			-- Also allow the `{` to be on the same line:
			local _, name2 = line:match("^%s*(.-)%s+([%w_:~]+)%s*%b()%s*%{")
			if name2 then
				return name2
			end
		end

		::continue::
	end
	return nil
end

local function count_function_defs_and_names(lines)
	local defs = {}

	for i, l in ipairs(lines or {}) do
		local line = (l or "")

		-- Detect a likely function-definition header line.
		-- We require (...) and either end-of-line OR an opening brace.
		-- This catches:
		--   int foo(int x)
		--   static int foo(int x) {
		-- and avoids most control statements like: if (x) { ... }
		--
		-- Guard against common keywords that could false-positive.
		if
			line:match("^%s*if%s*%(")
			or line:match("^%s*else%s+if%s*%(")
			or line:match("^%s*else%s*$")
			or line:match("^%s*for%s*%(")
			or line:match("^%s*while%s*%(")
			or line:match("^%s*switch%s*%(")
			or line:match("^%s*return%s")
		then
			goto continue
		end

		local _, name = line:match("^%s*(.-)%s+([%w_:~]+)%s*%b()%s*%{")
		if name then
			table.insert(defs, { line = vim.trim(line), name = name, idx = i })
			goto continue
		end

		-- Signature with brace on next line: count the signature line as a def start.
		local _, name2 = line:match("^%s*(.-)%s+([%w_:~]+)%s*%b()%s*$")
		if name2 then
			-- Only count it if the NEXT nonblank line is "{"
			for j = i + 1, math.min(i + 6, #lines) do
				local nxt = lines[j] or ""
				if vim.trim(nxt) == "" then
					-- skip blanks
				elseif nxt:match("^%s*%{") then
					table.insert(defs, { line = vim.trim(line), name = name2, idx = i })
					break
				else
					break
				end
			end
		end

		::continue::
	end

	return defs
end

local function violates_refactor_single_function(original_selection_text, candidate_lines)
	local orig_name = extract_first_function_name(original_selection_text)
	if not orig_name then
		return false, nil
	end

	local defs = count_function_defs_and_names(candidate_lines)

	if #defs == 0 then
		return true,
			{
				"Refactor guard: rejected candidate output.",
				"Reason: no function definition detected in candidate output.",
			}
	end

	if #defs > 1 then
		local out = {
			"Refactor guard: rejected candidate output.",
			"Reason: candidate contains multiple function definitions (injection / helper creation).",
			"Detected function defs:",
		}
		for _, d in ipairs(defs) do
			table.insert(out, string.format("%d | %s", d.idx, d.line))
		end
		return true, out
	end

	-- Exactly one function definition: ensure it is the SAME function.
	if defs[1].name ~= orig_name then
		return true,
			{
				"Refactor guard: rejected candidate output.",
				("Reason: function name changed or new helper introduced (%s -> %s)."):format(orig_name, defs[1].name),
				("Candidate def: %d | %s"):format(defs[1].idx, defs[1].line),
			}
	end

	return false, nil
end

-- -------------------------------------------------------------------
-- Clang validation (arg-safe, telemetry)
-- -------------------------------------------------------------------

local function system_run(argv)
	-- Neovim 0.10+: vim.system
	if not vim.system then
		return { code = 127, stdout = "", stderr = "vim.system not available", signal = nil }
	end

	local res = vim.system(argv, { text = true }):wait()
	return {
		code = res.code or 1,
		stdout = res.stdout or "",
		stderr = res.stderr or "",
		signal = res.signal, -- may be nil depending on platform
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

local function trim_blank_edges(lines)
	-- If you already have parse.trim_blank_edges you can call that instead.
	local first = 1
	local last = #lines
	while first <= last and vim.trim(lines[first] or "") == "" do
		first = first + 1
	end
	while last >= first and vim.trim(lines[last] or "") == "" do
		last = last - 1
	end
	if first > last then
		return {}
	end
	return vim.list_slice(lines, first, last)
end

local function too_large_rewrite(body, want_lines)
	-- Guard against Codex dumping huge output when asked to rewrite a small selection.
	-- Allow modest growth (refactors often add/adjust braces, comments, etc.)
	local n = #body
	if n == 0 then
		return true, "empty output"
	end
	local max_abs = 300
	if n > max_abs then
		return true, string.format("output too large (%d lines)", n)
	end
	if want_lines and want_lines > 0 then
		local max_mul = 4
		if n > (want_lines * max_mul) then
			return true, string.format("output grew too much (%d → %d lines)", want_lines, n)
		end
	end
	return false, nil
end

local function hrtime_ms()
	-- uv.hrtime() is nanoseconds
	return math.floor((uv.hrtime() or 0) / 1e6)
end

-- -------------------------------------------------------------------
-- C/C++ syntax validation safety net (clang preflight)
-- -------------------------------------------------------------------

local function is_cc_ft(ft)
	return prompt.is_c_family and prompt.is_c_family(ft or "") == true
end

local function clang_exe_for_ft(ft)
	-- Prefer clang++ for C++-ish, clang for C
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

-- Build a temp file representing the CURRENT BUFFER with a candidate range replacement applied,
-- then run clang/clang++ -fsyntax-only on it.
--
-- Returns:
--   ok:boolean, diag_lines:table<string>, temp_path:string, meta:table
-- meta:
--   { argv = {..}, code = int, signal = int|nil, elapsed_ms = int, skipped = boolean|nil, reason = string|nil }
local function clang_preflight_range_replace(bufnr, ft, start_line, end_line, replacement_lines)
	bufnr = bufnr or 0
	ft = ft or (vim.bo[bufnr].filetype or "")

	local meta = {
		argv = {},
		code = nil,
		signal = nil,
		elapsed_ms = nil,
	}

	-- If we can't run clang, don't block writes.
	local exe = clang_exe_for_ft(ft)
	if vim.fn.executable(exe) ~= 1 then
		meta.skipped = true
		meta.reason = exe .. " not found in PATH"
		return true, { "clang preflight skipped: " .. exe .. " not found in PATH" }, "", meta
	end

	-- If vim.system isn't available, skip (arg-safe runner not available).
	if not vim.system then
		meta.skipped = true
		meta.reason = "vim.system not available"
		return true, { "clang preflight skipped: vim.system not available" }, "", meta
	end

	-- Read buffer lines and apply replacement in-memory.
	local orig = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false) -- 0-based, end exclusive
	local new_lines = {}

	-- start_line/end_line are 1-based, end_line inclusive
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

	-- Write temp file.
	local tmpdir = vim.fn.tempname()
	pcall(vim.fn.mkdir, tmpdir, "p")

	local ext = (ft == "c") and ".c" or ".cpp"
	local tmppath = tmpdir .. "/0" .. ext
	vim.fn.writefile(new_lines, tmppath)

	-- Run clang (arg-safe).
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

	-- clang writes diagnostics mostly to stderr; fall back to stdout if empty
	local diag = split_nonempty_lines(res.stderr)
	if #diag == 0 then
		diag = split_nonempty_lines(res.stdout)
	end

	return false, diag, tmppath, meta
end

local function open_clang_rejection_scratch(opts)
	-- opts:
	--  title, ft, user_instruction, start_line, end_line, candidate_lines, clang_lines, temp_path, meta
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
	if meta and meta.argv and #meta.argv > 0 then
		report[#report + 1] = "  clang argv: " .. table.concat(meta.argv, " ")
	end
	if meta and meta.code ~= nil then
		report[#report + 1] = "  exit code: " .. tostring(meta.code)
	end
	if meta and meta.signal ~= nil then
		report[#report + 1] = "  signal: " .. tostring(meta.signal)
	end
	if meta and meta.elapsed_ms ~= nil then
		report[#report + 1] = "  elapsed: " .. tostring(meta.elapsed_ms) .. "ms"
	end
	if meta and meta.skipped then
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

local function write_tempfile(lines, suffix)
	local path = vim.fn.tempname() .. (suffix or "")
	vim.fn.writefile(lines or {}, path)
	return path
end

local function build_local_unified_diff(original_lines, candidate_lines, ft)
	local suffix = ".txt"
	ft = ft or ""

	if ft == "c" then
		suffix = ".c"
	elseif ft == "cpp" or ft == "cxx" or ft == "cc" or ft == "objc" or ft == "objcpp" then
		suffix = ".cpp"
	end

	local old_path = write_tempfile(original_lines or {}, suffix)
	local new_path = write_tempfile(candidate_lines or {}, suffix)

	local exe = "diff"
	if vim.fn.executable(exe) ~= 1 then
		return nil, { "Local diff preview unavailable: `diff` not found in PATH." }
	end

	local res = system_run({ exe, "-u", old_path, new_path })

	-- diff exit codes:
	--   0 = no differences
	--   1 = differences found
	--   >1 = actual error
	if res.code ~= 0 and res.code ~= 1 then
		local err = split_nonempty_lines(res.stderr)
		if #err == 0 then
			err = split_nonempty_lines(res.stdout)
		end
		if #err == 0 then
			err = { "Failed to build local unified diff." }
		end
		return nil, err
	end

	local diff_lines = split_nonempty_lines(res.stdout)

	if res.code == 0 or #diff_lines == 0 then
		return {}, nil
	end

	return diff_lines, nil
end

local function open_safe_diff_preview(diff_lines, title, on_confirm)
	title = title or "Codex Safe Diff Preview"

	open_scratch(diff_lines or {}, "diff", title)

	local bufnr = vim.api.nvim_get_current_buf()

	vim.bo[bufnr].modifiable = false

	vim.keymap.set("n", "<leader>ca", function()
		local ok = true
		if on_confirm then
			ok = on_confirm()
		end

		if ok ~= false and vim.api.nvim_buf_is_valid(bufnr) then
			vim.api.nvim_buf_delete(bufnr, { force = true })
		end
	end, {
		buffer = bufnr,
		silent = true,
		desc = "Codex: confirm preview apply",
	})

	vim.keymap.set("n", "q", function()
		if vim.api.nvim_buf_is_valid(bufnr) then
			vim.api.nvim_buf_delete(bufnr, { force = true })
		end
	end, {
		buffer = bufnr,
		silent = true,
		desc = "Close preview",
	})

	vim.notify("Diff ready. Press <leader>ca to validate and apply.", vim.log.levels.INFO, { title = "Codex" })
end

-- -------------------------------------------------------------------
-- Job runners
-- -------------------------------------------------------------------

-- Run codex exec with the INPUT embedded in the prompt (no stdin).
local function run_codex_embedded(input, instruction, callback, ft)
	local out_stdout, out_stderr = {}, {}

	local lang = prompt.fence_lang(ft or "c")
	local full_prompt = instruction .. "\n\n---\nHere is the code/snippet:\n```" .. lang .. "\n" .. input .. "\n```"

	local current_mode = mode.current()
	ui_start("Codex [" .. current_mode .. "] working…")

	codex_log.write("start", {
		mode = current_mode,
		file = vim.api.nvim_buf_get_name(0),
	})

	local job_id = vim.fn.jobstart({ "codex", "exec", "--skip-git-repo-check", full_prompt }, {

		pty = true,
		env = {
			PAGER = "cat",
			GIT_PAGER = "cat",
			LESS = "-FRSX",
			NO_COLOR = "1",
			TERM = "xterm-256color",
		},

		stdout_buffered = true,
		on_stdout = function(_, data)
			if data then
				vim.list_extend(out_stdout, data)
			end
		end,

		stderr_buffered = true,
		on_stderr = function(_, data)
			if data then
				vim.list_extend(out_stderr, data)
			end
		end,

		on_exit = function(_, code)
			vim.schedule(function()
				if code ~= 0 then
					ui_stop("Codex [" .. mode.current() .. "] failed (see output)", vim.log.levels.ERROR)
					if #out_stderr > 0 then
						open_scratch(out_stderr, "text", "Codex STDERR")
					end
					return
				end

				ui_stop("Codex [" .. mode.current() .. "] done", vim.log.levels.INFO)

				local output = (#out_stdout > 0) and out_stdout or out_stderr

				local cleaned = {}
				for _, line in ipairs(output) do
					line = (line or ""):gsub("\r", "")
					if not line:match("^Skipping markdown%-preview build") then
						table.insert(cleaned, line)
					end
				end

				codex_log.write("response", {
					mode = current_mode,
					bytes = #table.concat(cleaned, "\n"),
				})

				if callback then
					callback(cleaned)
				end
			end)
		end,
	})

	if job_id <= 0 then
		ui_stop("Failed to start Codex job", vim.log.levels.ERROR)
	end
end

-- -------------------------------------------------------------------
-- Public API
-- -------------------------------------------------------------------

function M.replace_current_function()
	local ft = vim.bo.filetype or "text"
	local start_line, end_line = get_current_function_range_cc()

	if not start_line or not end_line then
		vim.notify("No enclosing function found at cursor", vim.log.levels.WARN, { title = "Codex" })
		return
	end

	local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
	local text = table.concat(lines, "\n")

	-- Route through your existing range rewrite path (with clang + guards)
	M.replace_range(text, start_line, end_line, ft)
end

function M.explain_current_line()
	local line = vim.fn.getline(".")
	local ft = vim.bo.filetype or ""
	local default_prompt = prompt.build_explain(ft)

	prompt_user({ prompt = "Codex explain: ", default = default_prompt }, function(user_prompt)
		run_codex_embedded(line, user_prompt, function(output)
			open_scratch(parse.clean_codex_output(output), "markdown", "Explain Line")
		end, ft)
	end)
end

function M.apply_inline_current_line()
	local line = vim.fn.getline(".")
	local lnum = vim.fn.line(".")
	local want_lines = 1
	local ft = vim.bo.filetype or ""

	prompt_user({ prompt = "Codex [" .. mode.current() .. "] instruction: " }, function(user_prompt)
		local out_stdout, out_stderr = {}, {}
		local p = prompt.build_apply(user_prompt, line)

		local current_mode = mode.current()
		ui_start("Codex [" .. current_mode .. "] working…")

		local job_id = vim.fn.jobstart({ "codex", "exec", "--skip-git-repo-check", p }, {
			stdout_buffered = true,
			stderr_buffered = true,

			on_stdout = function(_, data)
				if data then
					vim.list_extend(out_stdout, data)
				end
			end,
			on_stderr = function(_, data)
				if data then
					vim.list_extend(out_stderr, data)
				end
			end,

			on_exit = function(_, code)
				vim.schedule(function()
					local raw = parse.normalize_lines((#out_stdout > 0) and out_stdout or out_stderr)

					if code ~= 0 then
						ui_stop("Codex [" .. mode.current() .. "] failed (see output)", vim.log.levels.ERROR)
						open_scratch(raw, "text", "Codex Apply (failed)")
						return
					end

					ui_stop("Codex [" .. mode.current() .. "] done", vim.log.levels.INFO)

					local body = parse.parse_apply_body(raw)

					if #body == 0 then
						vim.notify("Apply: no marked replacement block found", vim.log.levels.WARN, { title = "Codex" })
						open_scratch(raw, "text", "Codex Apply (unparsed)")
						return
					end

					if #body == 1 and vim.trim(body[1]) == "ERROR" then
						vim.notify("Apply: Codex returned ERROR", vim.log.levels.ERROR, { title = "Codex" })
						open_scratch(raw, "text", "Codex Apply (ERROR)")
						return
					end

					if #body ~= want_lines then
						vim.notify(
							string.format("Apply: wrong line count (got %d, want %d)", #body, want_lines),
							vim.log.levels.ERROR,
							{ title = "Codex" }
						)
						open_scratch(raw, "text", "Codex Apply (wrong line count)")
						return
					end

					-- clang preflight for C/C++
					if is_cc_ft(ft) then
						local ok, clang_lines, tmppath, meta = clang_preflight_range_replace(0, ft, lnum, lnum, body)
						if not ok then
							open_clang_rejection_scratch({
								title = "Codex Rejected (clang)",
								ft = ft,
								user_instruction = user_prompt,
								start_line = lnum,
								end_line = lnum,
								candidate_lines = body,
								clang_lines = clang_lines,
								temp_path = tmppath,
								meta = meta,
							})
							vim.notify("clang rejected rewrite; not applied", vim.log.levels.ERROR, { title = "Codex" })
							return
						end
					end

					vim.api.nvim_buf_set_lines(0, lnum - 1, lnum, false, body)
				end)
			end,
		})

		if job_id <= 0 then
			ui_stop("Failed to start Codex job", vim.log.levels.ERROR)
		end
	end)
end

function M.replace_range(text, start_line, end_line, ft)
	if not text or vim.trim(text) == "" then
		vim.notify("No selection captured", vim.log.levels.WARN, { title = "Codex" })
		return
	end

	ft = ft or (vim.bo.filetype or "text")
	local want_lines = lines_count(text)

	prompt_user({ prompt = "Codex [" .. mode.current() .. "] instruction: " }, function(user_prompt)
		local p = prompt.build_raw_rewrite(user_prompt, ft, want_lines)

		run_codex_embedded(text, p, function(output)
			local body = parse.prefer_clean_answer(output)
			body = collapse_if_doubled(body, want_lines)

			if parse.looks_like_chatty_output(body) then
				open_scratch(body, "text", "Codex Output (rule break)")
				vim.notify("Codex violated output rules; not applying", vim.log.levels.WARN, { title = "Codex" })
				return
			end

			body = trim_blank_edges(body)

			local bad, why = too_large_rewrite(body, want_lines)
			if bad then
				open_scratch(body, "text", "Codex Output (rejected)")
				vim.notify("Codex output rejected: " .. (why or "invalid"), vim.log.levels.WARN, { title = "Codex" })
				return
			end

			-- Refactor-mode structural guard (prevents extra helper/function injections)
			if mode.current() == "refactor" then
				local bad2, why_lines = violates_refactor_single_function(text, body)
				if bad2 then
					open_scratch(why_lines, "text", "Codex Output (rejected)")
					vim.notify("Codex output rejected by refactor guard", vim.log.levels.WARN, { title = "Codex" })
					return
				end
			end

			-- clang preflight for C/C++
			if is_cc_ft(ft) then
				local ok, clang_lines, tmppath, meta = clang_preflight_range_replace(0, ft, start_line, end_line, body)
				if not ok then
					open_clang_rejection_scratch({
						title = "Codex Rejected (clang)",
						ft = ft,
						user_instruction = user_prompt,
						start_line = start_line,
						end_line = end_line,
						candidate_lines = body,
						clang_lines = clang_lines,
						temp_path = tmppath,
						meta = meta,
					})
					vim.notify("clang rejected rewrite; not applied", vim.log.levels.ERROR, { title = "Codex" })
					return
				end
			end

			vim.api.nvim_buf_set_lines(0, start_line - 1, end_line, false, body)
		end, ft)
	end)
end

function M.preview_diff_current_line()
	local line = vim.fn.getline(".")
	local ft = vim.bo.filetype or ""

	local function extract_unified_diff(lines)
		local out = {}
		local in_diff = false
		local saw_header = false
		local saw_hunk = false

		for _, l in ipairs(lines or {}) do
			l = (l or ""):gsub("\r", "")
			if l:match("^%-%-%- ") then
				if saw_header and saw_hunk then
					break
				end
				in_diff = true
				saw_header = true
				out[#out + 1] = l
				goto continue
			end
			if in_diff and l:match("^%+%+%+ ") then
				out[#out + 1] = l
				goto continue
			end
			if in_diff and l:match("^@@") then
				saw_hunk = true
				out[#out + 1] = l
				goto continue
			end
			if in_diff and saw_hunk and l:match("^[ +-]") then
				out[#out + 1] = l
				goto continue
			end
			::continue::
		end
		return parse.trim_blank_edges(out)
	end

	prompt_user({ prompt = "Codex instruction (diff): ", default = "" }, function(user_prompt)
		local diff_prompt = prompt.build_unified_diff(user_prompt)

		run_codex_embedded(line, diff_prompt, function(output)
			local raw = parse.normalize_lines(output or {})
			local cleaned = parse.clean_codex_output(raw)

			local diff = extract_unified_diff(raw)
			if #diff == 0 then
				diff = extract_unified_diff(cleaned)
			end

			if #diff == 0 then
				vim.notify("No valid unified diff found in Codex output", vim.log.levels.WARN, { title = "Codex" })
				open_scratch(cleaned, "text", "Codex Diff (unparsed)")
				return
			end

			open_scratch(diff, "diff", "Diff Preview")
			vim.notify("Diff ready (preview only)", vim.log.levels.INFO, { title = "Codex" })
		end, ft)
	end)
end

function M.explain_text(text)
	local ft = vim.bo.filetype or ""
	local default_prompt = prompt.build_explain(ft)

	prompt_user({ prompt = "Codex explain: ", default = default_prompt }, function(user_prompt)
		run_codex_embedded(text, user_prompt, function(output)
			open_scratch(parse.clean_codex_output(output), "markdown", "Explain Selection")
		end, ft)
	end)
end

function M.explain_selection()
	local text = select(1, collect_selection())
	local ft = vim.bo.filetype or ""
	local default_prompt = prompt.build_explain(ft)

	prompt_user({ prompt = "Codex explain: ", default = default_prompt }, function(user_prompt)
		run_codex_embedded(text, user_prompt, function(output)
			open_scratch(parse.clean_codex_output(output), "markdown", "Explain Selection")
		end, ft)
	end)
end

function M.replace_selection()
	local text, start_line, end_line = collect_selection()
	if not text or vim.trim(text) == "" then
		vim.notify("No selection captured", vim.log.levels.WARN, { title = "Codex" })
		return
	end

	local ft = vim.bo.filetype or "text"
	local want_lines = lines_count(text)

	prompt_user({ prompt = "Codex [" .. mode.current() .. "] instruction: " }, function(user_prompt)
		local p = prompt.build_raw_rewrite(user_prompt, ft, want_lines)

		run_codex_embedded(text, p, function(output)
			local body = parse.prefer_clean_answer(output)
			body = collapse_if_doubled(body, want_lines)

			if parse.looks_like_chatty_output(body) then
				open_scratch(body, "text", "Codex Output (rule break)")
				vim.notify("Codex violated output rules; not applying", vim.log.levels.WARN, { title = "Codex" })
				return
			end

			body = trim_blank_edges(body)

			local bad, why = too_large_rewrite(body, want_lines)
			if bad then
				open_scratch(body, "text", "Codex Output (rejected)")
				vim.notify("Codex output rejected: " .. (why or "invalid"), vim.log.levels.WARN, { title = "Codex" })
				return
			end

			-- Refactor-mode structural guard (prevents extra helper/function injections)
			if mode.current() == "refactor" then
				local bad2, why_lines = violates_refactor_single_function(text, body)
				if bad2 then
					open_scratch(why_lines, "text", "Codex Output (rejected)")
					vim.notify("Codex output rejected by refactor guard", vim.log.levels.WARN, { title = "Codex" })
					return
				end
			end

			-- clang preflight for C/C++
			if is_cc_ft(ft) then
				local ok, clang_lines, tmppath, meta = clang_preflight_range_replace(0, ft, start_line, end_line, body)
				if not ok then
					open_clang_rejection_scratch({
						title = "Codex Rejected (clang)",
						ft = ft,
						user_instruction = user_prompt,
						start_line = start_line,
						end_line = end_line,
						candidate_lines = body,
						clang_lines = clang_lines,
						temp_path = tmppath,
						meta = meta,
					})
					vim.notify("clang rejected rewrite; not applied", vim.log.levels.ERROR, { title = "Codex" })
					return
				end
			end

			vim.api.nvim_buf_set_lines(0, start_line - 1, end_line, false, body)
		end, ft)
	end)
end

function M.open_output_scratch()
	local text = select(1, collect_selection())
	if not text or vim.trim(text) == "" then
		vim.notify("No selection captured", vim.log.levels.WARN, { title = "Codex" })
		return
	end

	local ft = vim.bo.filetype or "text"

	prompt_user({ prompt = "Codex [" .. mode.current() .. "] instruction: " }, function(user_prompt)
		local p = prompt.build_raw_rewrite(user_prompt, ft, nil)
		run_codex_embedded(text, p, function(output)
			local body = parse.prefer_clean_answer(output)
			body = collapse_if_doubled(body, nil)
			open_scratch(body, nil, "Codex Output")
		end, ft)
	end)
end

function M.save_output_to_file_text(text)
	if not text or vim.trim(text) == "" then
		vim.notify("No selection captured", vim.log.levels.WARN, { title = "Codex" })
		return
	end
	local ft = vim.bo.filetype or "text"

	prompt_user({ prompt = "Codex [" .. mode.current() .. "] instruction: " }, function(user_prompt)
		prompt_user({ prompt = "Save output as: " }, function(filename)
			local p = prompt.build_raw_rewrite(user_prompt, ft, nil)
			run_codex_embedded(text, p, function(output)
				local to_write = parse.prefer_clean_answer(output)
				to_write = collapse_if_doubled(to_write, nil)

				if parse.looks_like_chatty_output(to_write) then
					open_scratch(to_write, "text", "Codex Output (rule break)")
					vim.notify(
						"Codex violated output rules; not writing file",
						vim.log.levels.WARN,
						{ title = "Codex" }
					)
					return
				end

				vim.cmd("edit " .. vim.fn.fnameescape(filename))
				vim.api.nvim_buf_set_lines(0, 0, -1, false, to_write)
				vim.cmd("write")
				vim.notify("Codex output written to " .. filename, vim.log.levels.INFO, { title = "Codex" })
			end, ft)
		end)
	end)
end

function M.apply_inline()
	local text, start_line, end_line = collect_selection()
	local want_lines = lines_count(text)
	local ft = vim.bo.filetype or ""

	prompt_user({ prompt = "Codex [" .. mode.current() .. "] instruction: " }, function(user_prompt)
		local out_stdout, out_stderr = {}, {}
		local p = prompt.build_apply(user_prompt, text)

		local current_mode = mode.current()
		ui_start("Codex [" .. current_mode .. "] working…")

		local job_id = vim.fn.jobstart({ "codex", "exec", "--skip-git-repo-check", p }, {
			stdout_buffered = true,
			stderr_buffered = true,

			on_stdout = function(_, data)
				if data then
					vim.list_extend(out_stdout, data)
				end
			end,
			on_stderr = function(_, data)
				if data then
					vim.list_extend(out_stderr, data)
				end
			end,

			on_exit = function(_, code)
				vim.schedule(function()
					local raw = parse.normalize_lines((#out_stdout > 0) and out_stdout or out_stderr)

					if code ~= 0 then
						ui_stop("Codex [" .. mode.current() .. "] failed (see output)", vim.log.levels.ERROR)
						open_scratch(raw, "text", "Codex Apply (failed)")
						return
					end

					ui_stop("Codex [" .. mode.current() .. "] done", vim.log.levels.INFO)

					local body = parse.parse_apply_body(raw)

					if #body == 0 then
						vim.notify("Apply: no marked replacement block found", vim.log.levels.WARN, { title = "Codex" })
						open_scratch(raw, "text", "Codex Apply (unparsed)")
						return
					end

					if #body == 1 and vim.trim(body[1]) == "ERROR" then
						vim.notify("Apply: Codex returned ERROR", vim.log.levels.ERROR, { title = "Codex" })
						open_scratch(raw, "text", "Codex Apply (ERROR)")
						return
					end

					if #body ~= want_lines then
						vim.notify(
							string.format("Apply: wrong line count (got %d, want %d)", #body, want_lines),
							vim.log.levels.ERROR,
							{ title = "Codex" }
						)
						open_scratch(raw, "text", "Codex Apply (wrong line count)")
						return
					end

					-- clang preflight for C/C++
					if is_cc_ft(ft) then
						local ok, clang_lines, tmppath, meta =
							clang_preflight_range_replace(0, ft, start_line, end_line, body)
						if not ok then
							open_clang_rejection_scratch({
								title = "Codex Rejected (clang)",
								ft = ft,
								user_instruction = user_prompt,
								start_line = start_line,
								end_line = end_line,
								candidate_lines = body,
								clang_lines = clang_lines,
								temp_path = tmppath,
								meta = meta,
							})
							vim.notify("clang rejected rewrite; not applied", vim.log.levels.ERROR, { title = "Codex" })
							return
						end
					end

					vim.api.nvim_buf_set_lines(0, start_line - 1, end_line, false, body)
				end)
			end,
		})

		if job_id <= 0 then
			ui_stop("Failed to start Codex job", vim.log.levels.ERROR)
		end
	end)
end

function M.safe_preview_confirm_apply_selection()
	local text, start_line, end_line = collect_selection()
	if not text or vim.trim(text) == "" then
		vim.notify("No selection captured", vim.log.levels.WARN, { title = "Codex" })
		return
	end

	local ft = vim.bo.filetype or ""
	local target_bufnr = vim.api.nvim_get_current_buf()
	local want_lines = lines_count(text)

	prompt_user({ prompt = "Codex [" .. mode.current() .. "] instruction: " }, function(user_prompt)
		local out_stdout, out_stderr = {}, {}
		local p = prompt.build_apply(user_prompt, text)

		local current_mode = mode.current()
		ui_start("Codex [" .. current_mode .. "] working…")

		local job_id = vim.fn.jobstart({ "codex", "exec", "--skip-git-repo-check", p }, {
			stdout_buffered = true,
			stderr_buffered = true,

			on_stdout = function(_, data)
				if data then
					vim.list_extend(out_stdout, data)
				end
			end,

			on_stderr = function(_, data)
				if data then
					vim.list_extend(out_stderr, data)
				end
			end,

			on_exit = function(_, code)
				vim.schedule(function()
					local raw = parse.normalize_lines((#out_stdout > 0) and out_stdout or out_stderr)

					if code ~= 0 then
						ui_stop("Codex [" .. mode.current() .. "] failed (see output)", vim.log.levels.ERROR)
						open_scratch(raw, "text", "Codex Safe Apply (failed)")
						return
					end

					ui_stop("Codex [" .. mode.current() .. "] done", vim.log.levels.INFO)

					local body = parse.parse_apply_body(raw)
					body = collapse_if_doubled(body, want_lines)

					if #body == 0 then
						vim.notify("Apply: no marked replacement block found", vim.log.levels.WARN, { title = "Codex" })
						open_scratch(raw, "text", "Codex Safe Apply (unparsed)")
						return
					end

					if #body == 1 and vim.trim(body[1]) == "ERROR" then
						vim.notify("Apply: Codex returned ERROR", vim.log.levels.ERROR, { title = "Codex" })
						open_scratch(raw, "text", "Codex Safe Apply (ERROR)")
						return
					end

					if parse.looks_like_chatty_output(body) then
						open_scratch(body, "text", "Codex Output (rule break)")
						vim.notify(
							"Codex violated output rules; not applying",
							vim.log.levels.WARN,
							{ title = "Codex" }
						)
						return
					end

					body = trim_blank_edges(body)

					local bad, why = too_large_rewrite(body, want_lines)
					if bad then
						open_scratch(body, "text", "Codex Output (rejected)")
						vim.notify(
							"Codex output rejected: " .. (why or "invalid"),
							vim.log.levels.WARN,
							{ title = "Codex" }
						)
						return
					end

					local original_lines = vim.fn.getline(start_line, end_line)
					local diff_lines, diff_err = build_local_unified_diff(original_lines, body, ft)

					if not diff_lines then
						open_scratch(
							diff_err or { "Failed to build diff preview." },
							"text",
							"Codex Diff Preview (error)"
						)
						vim.notify("Failed to build local diff preview", vim.log.levels.ERROR, { title = "Codex" })
						return
					end

					if #diff_lines == 0 then
						vim.notify("No changes produced", vim.log.levels.INFO, { title = "Codex" })
						return
					end

					open_safe_diff_preview(diff_lines, "Codex Safe Diff Preview", function()
						-- clang preflight for C/C++
						if is_cc_ft(ft) then
							local ok, clang_lines, tmppath, meta =
								clang_preflight_range_replace(target_bufnr, ft, start_line, end_line, body)
							if not ok then
								open_clang_rejection_scratch({
									title = "Codex Rejected (clang)",
									ft = ft,
									user_instruction = user_prompt,
									start_line = start_line,
									end_line = end_line,
									candidate_lines = body,
									clang_lines = clang_lines,
									temp_path = tmppath,
									meta = meta,
								})
								vim.notify(
									"clang rejected rewrite; not applied",
									vim.log.levels.ERROR,
									{ title = "Codex" }
								)
								return false
							end
						end

						vim.api.nvim_buf_set_lines(target_bufnr, start_line - 1, end_line, false, body)
						vim.notify("Preview confirmed and applied", vim.log.levels.INFO, { title = "Codex" })
						return true
					end)
				end)
			end,
		})

		if job_id <= 0 then
			ui_stop("Failed to start Codex job", vim.log.levels.ERROR)
		end
	end)
end

function M.safe_preview_confirm_apply_current_function()
	local ft = vim.bo.filetype or ""
	local start_line, end_line = get_current_function_range_cc()

	if not start_line or not end_line then
		vim.notify("No enclosing function found at cursor", vim.log.levels.WARN, { title = "Codex" })
		return
	end

	local target_bufnr = vim.api.nvim_get_current_buf()

	local original_lines = vim.api.nvim_buf_get_lines(target_bufnr, start_line - 1, end_line, false)
	local original_text = table.concat(original_lines, "\n")

	prompt_user({ prompt = "Codex [" .. mode.current() .. "] refactor: " }, function(user_prompt)
		local out_stdout, out_stderr = {}, {}
		local p = prompt.build_apply(user_prompt, original_text)

		local current_mode = mode.current()
		ui_start("Codex [" .. current_mode .. "] working…")

		local job_id = vim.fn.jobstart({ "codex", "exec", "--skip-git-repo-check", p }, {
			stdout_buffered = true,
			stderr_buffered = true,

			on_stdout = function(_, data)
				if data then
					vim.list_extend(out_stdout, data)
				end
			end,

			on_stderr = function(_, data)
				if data then
					vim.list_extend(out_stderr, data)
				end
			end,

			on_exit = function(_, code)
				vim.schedule(function()
					local raw = parse.normalize_lines((#out_stdout > 0) and out_stdout or out_stderr)

					if code ~= 0 then
						ui_stop("Codex [" .. mode.current() .. "] failed (see output)", vim.log.levels.ERROR)
						open_scratch(raw, "text", "Codex Safe Refactor (failed)")
						return
					end

					ui_stop("Codex [" .. mode.current() .. "] done", vim.log.levels.INFO)

					local body = parse.parse_apply_body(raw)
					body = collapse_if_doubled(body, nil)

					if #body == 0 then
						vim.notify("Refactor: no replacement block found", vim.log.levels.WARN, { title = "Codex" })
						open_scratch(raw, "text", "Codex Safe Refactor (unparsed)")
						return
					end

					if #body == 1 and vim.trim(body[1]) == "ERROR" then
						vim.notify("Refactor: Codex returned ERROR", vim.log.levels.ERROR, { title = "Codex" })
						open_scratch(raw, "text", "Codex Safe Refactor (ERROR)")
						return
					end

					if parse.looks_like_chatty_output(body) then
						open_scratch(body, "text", "Codex Output (rule break)")
						vim.notify(
							"Codex violated output rules; not applying",
							vim.log.levels.WARN,
							{ title = "Codex" }
						)
						return
					end

					body = trim_blank_edges(body)

					local bad, why = too_large_rewrite(body, #original_lines)
					if bad then
						open_scratch(body, "text", "Codex Output (rejected)")
						vim.notify(
							"Codex output rejected: " .. (why or "invalid"),
							vim.log.levels.WARN,
							{ title = "Codex" }
						)
						return
					end

					-- Refactor guard: enforce single function
					local bad2, why_lines = violates_refactor_single_function(original_text, body)
					if bad2 then
						open_scratch(why_lines, "text", "Codex Output (refactor rejected)")
						vim.notify("Refactor rejected by structural guard", vim.log.levels.WARN, { title = "Codex" })
						return
					end

					local diff_lines, diff_err = build_local_unified_diff(original_lines, body, ft)

					if not diff_lines then
						open_scratch(
							diff_err or { "Failed to build diff preview." },
							"text",
							"Codex Diff Preview (error)"
						)
						vim.notify("Failed to build local diff preview", vim.log.levels.ERROR, { title = "Codex" })
						return
					end

					if #diff_lines == 0 then
						vim.notify("No changes produced", vim.log.levels.INFO, { title = "Codex" })
						return
					end

					open_safe_diff_preview(diff_lines, "Codex Function Refactor Preview", function()
						if is_cc_ft(ft) then
							local ok, clang_lines, tmppath, meta =
								clang_preflight_range_replace(target_bufnr, ft, start_line, end_line, body)

							if not ok then
								open_clang_rejection_scratch({
									title = "Codex Refactor Rejected (clang)",
									ft = ft,
									user_instruction = user_prompt,
									start_line = start_line,
									end_line = end_line,
									candidate_lines = body,
									clang_lines = clang_lines,
									temp_path = tmppath,
									meta = meta,
								})

								vim.notify(
									"clang rejected refactor; not applied",
									vim.log.levels.ERROR,
									{ title = "Codex" }
								)
								return false
							end
						end

						vim.api.nvim_buf_set_lines(target_bufnr, start_line - 1, end_line, false, body)

						vim.notify("Refactor preview confirmed and applied", vim.log.levels.INFO, { title = "Codex" })
						return true
					end)
				end)
			end,
		})

		if job_id <= 0 then
			ui_stop("Failed to start Codex job", vim.log.levels.ERROR)
		end
	end)
end

function M.preview_diff()
	local selected = select(1, collect_selection())

	local function extract_unified_diff(lines)
		local out = {}
		local in_diff = false
		local saw_header = false
		local saw_hunk = false

		for _, line in ipairs(lines or {}) do
			line = (line or ""):gsub("\r", "")

			if line:match("^%-%-%- ") then
				if saw_header and saw_hunk then
					break
				end
				in_diff = true
				saw_header = true
				out[#out + 1] = line
				goto continue
			end

			if in_diff and line:match("^%+%+%+ ") then
				out[#out + 1] = line
				goto continue
			end

			if in_diff and line:match("^@@") then
				saw_hunk = true
				out[#out + 1] = line
				goto continue
			end

			if in_diff and saw_hunk then
				if line:match("^[ +-]") then
					out[#out + 1] = line
					goto continue
				end
			end

			::continue::
		end

		return parse.trim_blank_edges(out)
	end

	prompt_user({ prompt = "Codex instruction (diff): ", default = "" }, function(user_prompt)
		local diff_prompt = prompt.build_unified_diff(user_prompt)
		local ft = vim.bo.filetype or ""

		run_codex_embedded(selected, diff_prompt, function(output)
			local raw = parse.normalize_lines(output or {})
			local cleaned = parse.clean_codex_output(raw)

			local diff = extract_unified_diff(raw)
			if #diff == 0 then
				diff = extract_unified_diff(cleaned)
			end

			if #diff == 0 then
				vim.notify("No valid unified diff found in Codex output", vim.log.levels.WARN, { title = "Codex" })
				open_scratch(cleaned, "text", "Codex Diff (unparsed)")
				return
			end

			open_scratch(diff, "diff", "Diff Preview")
			vim.notify("Diff ready (preview only)", vim.log.levels.INFO, { title = "Codex" })
		end, ft)
	end)
end

function M.run_current_line()
	local line = vim.fn.getline(".")
	local lnum = vim.fn.line(".")
	local ft = vim.bo.filetype or "text"

	prompt_user({ prompt = "Codex [" .. mode.current() .. "] instruction: " }, function(user_prompt)
		local p = prompt.build_raw_rewrite(user_prompt, ft, 1)
		run_codex_embedded(line, p, function(output)
			local body = parse.prefer_clean_answer(output)
			body = collapse_if_doubled(body, 1)

			if parse.looks_like_chatty_output(body) then
				open_scratch(body, "text", "Codex Output (rule break)")
				vim.notify("Codex violated output rules; not applying", vim.log.levels.WARN, { title = "Codex" })
				return
			end

			-- clang preflight for C/C++
			if is_cc_ft(ft) then
				local ok, clang_lines, tmppath, meta =
					clang_preflight_range_replace(0, ft, lnum, lnum, { body[1] or "" })
				if not ok then
					open_clang_rejection_scratch({
						title = "Codex Rejected (clang)",
						ft = ft,
						user_instruction = user_prompt,
						start_line = lnum,
						end_line = lnum,
						candidate_lines = { body[1] or "" },
						clang_lines = clang_lines,
						temp_path = tmppath,
						meta = meta,
					})
					vim.notify("clang rejected rewrite; not applied", vim.log.levels.ERROR, { title = "Codex" })
					return
				end
			end

			local new_line = body[1] or line
			vim.api.nvim_buf_set_lines(0, lnum - 1, lnum, false, { new_line })
		end, ft)
	end)
end

function M.run_entire_file()
	local buf = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	local text = table.concat(buf, "\n")
	local ft = vim.bo.filetype or "text"

	prompt_user({ prompt = "Codex [" .. mode.current() .. "] instruction: " }, function(user_prompt)
		local p = prompt.build_entire_file_rewrite(user_prompt)

		run_codex_embedded(text, p, function(output)
			local body = parse.prefer_clean_answer(output)
			body = collapse_if_doubled(body, nil)

			if parse.looks_like_file_prose(body) or parse.looks_like_chatty_output(body) then
				open_scratch(body, "text", "Codex File Output (refused overwrite)")
				vim.notify(
					"Codex returned non-file output; not overwriting buffer",
					vim.log.levels.WARN,
					{ title = "Codex" }
				)
				return
			end

			-- clang preflight for C/C++ (whole file overwrite)
			if is_cc_ft(ft) then
				local ok, clang_lines, tmppath, meta = clang_preflight_range_replace(0, ft, 1, #buf, body)
				if not ok then
					open_clang_rejection_scratch({
						title = "Codex Rejected (clang)",
						ft = ft,
						user_instruction = user_prompt,
						start_line = 1,
						end_line = #buf,
						candidate_lines = body,
						clang_lines = clang_lines,
						temp_path = tmppath,
						meta = meta,
					})
					vim.notify("clang rejected file rewrite; not applied", vim.log.levels.ERROR, { title = "Codex" })
					return
				end
			end

			vim.api.nvim_buf_set_lines(0, 0, -1, false, body)
		end, ft)
	end)
end

function M.patch_buffer()
	local filename = vim.fn.expand("%:p")
	prompt_user({ prompt = "Codex patch: " }, function(p_text)
		local cmd = string.format("codex --diff %q %q", p_text, filename)
		vim.cmd("botright split | term " .. cmd)
	end)
end

function M.scratchpad_prompt(default_prompt)
	prompt_user({ prompt = "Codex scratch: ", default = default_prompt or "" }, function(p_text)
		local text = vim.api.nvim_buf_get_lines(0, 0, -1, false)
		local buftext = table.concat(text, "\n")
		local ft = vim.bo.filetype or ""

		run_codex_embedded(buftext, p_text, function(output)
			open_scratch(parse.clean_codex_output(output), "markdown")
		end, ft)
	end)
end

return M
