-- ~/.config/nvim/lua/codex_cli.lua
local M = {}

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
	local start_pos = vim.fn.getpos("'<")
	local end_pos = vim.fn.getpos("'>")
	local start_line, end_line = start_pos[2], end_pos[2]

	if start_line > end_line then
		start_line, end_line = end_line, start_line
	end

	local lines = vim.fn.getline(start_line, end_line)
	return table.concat(lines, "\n"), start_line, end_line
end

local function normalize_lines(lines)
	local out = {}
	for _, l in ipairs(lines or {}) do
		if l ~= nil then
			out[#out + 1] = (l:gsub("\r", ""))
		end
	end
	return out
end

local function lines_count(s)
	if not s or s == "" then
		return 0
	end
	local _, n = s:gsub("\n", "\n")
	return n + 1
end

local function trim_blank_edges(lines)
	local out = vim.deepcopy(lines or {})
	local function blank(s)
		return s == nil or s:match("^%s*$")
	end
	while #out > 0 and blank(out[1]) do
		table.remove(out, 1)
	end
	while #out > 0 and blank(out[#out]) do
		table.remove(out)
	end
	return out
end

-- Keep only the assistant answer portion from Codex CLI output.
local function clean_codex_output(lines)
	local out = {}
	local capture = false

	for _, line in ipairs(lines or {}) do
		if line == nil then
			goto continue
		end

		line = line:gsub("\r", "")

		-- Start capturing ONLY after the transcript marker.
		if vim.trim(line) == "codex" then
			capture = true
			goto continue
		end

		if not capture then
			goto continue
		end

		-- Drop common noise
		if line:match("^tokens used") then
			goto continue
		end
		if line:match("^Press ENTER") then
			goto continue
		end
		if line:match("^Skipping markdown%-preview build") then
			goto continue
		end

		-- Drop lines that are just a number (e.g. "2,665")
		if line:match("^%s*%d[%d,]*%s*$") then
			goto continue
		end

		table.insert(out, line)

		::continue::
	end

	if #out == 0 then
		return lines or {}
	end

	-- Trim leading/trailing empty lines
	local function is_blank(s)
		return s == nil or s:match("^%s*$")
	end
	while #out > 0 and is_blank(out[1]) do
		table.remove(out, 1)
	end
	while #out > 0 and is_blank(out[#out]) do
		table.remove(out)
	end

	-- De-dupe consecutive identical lines (keeps blank lines)
	local dedup = {}
	local prev = nil
	for _, l in ipairs(out) do
		if l ~= prev then
			table.insert(dedup, l)
		end
		prev = l
	end
	out = dedup

	-- BLOCK DEDUPE: if output is exactly repeated twice, keep only the first half.
	local function strip_trailing_blanks(t)
		local r = vim.deepcopy(t)
		while #r > 0 and is_blank(r[#r]) do
			table.remove(r)
		end
		return r
	end

	local function slice(t, a, b)
		local r = {}
		for i = a, b do
			r[#r + 1] = t[i]
		end
		return r
	end

	local function equal(a, b)
		if #a ~= #b then
			return false
		end
		for i = 1, #a do
			if a[i] ~= b[i] then
				return false
			end
		end
		return true
	end

	local cleaned = strip_trailing_blanks(out)
	local n = #cleaned
	if n >= 6 and (n % 2 == 0) then
		local half = n / 2
		local a = slice(cleaned, 1, half)
		local b = slice(cleaned, half + 1, n)
		if equal(a, b) then
			return a
		end
	end

	return out
end

local function extract_between_markers(lines, begin_mark, end_mark)
	local out, on = {}, false
	for _, l in ipairs(lines or {}) do
		local t = vim.trim(l or "")
		if t == begin_mark then
			on = true
			goto continue
		end
		if t == end_mark then
			break
		end
		if on then
			table.insert(out, l)
		end
		::continue::
	end
	return trim_blank_edges(out)
end

-- Prefer cleaned answer (codex section); if that fails, fall back to normalized output.
local function prefer_clean_answer(lines)
	local raw = normalize_lines(lines or {})
	local cleaned = clean_codex_output(raw)
	cleaned = trim_blank_edges(cleaned)

	if #cleaned > 0 then
		return cleaned
	end

	-- fallback: at least return something readable
	return trim_blank_edges(raw)
end

-- -------------------------------------------------------------------
-- Language helpers (prompt/fence awareness)
-- -------------------------------------------------------------------

local C_FAMILY = {
	c = true,
	cpp = true,
	objc = true,
	objcpp = true,
	cuda = true,
}

local function is_c_family(ft)
	return C_FAMILY[ft or ""] == true
end

-- Map Neovim filetypes to reasonable fenced-block language labels.
local FENCE_FT_MAP = {
	[""] = "text",
	text = "text",
	typescriptreact = "tsx",
	javascriptreact = "jsx",
	sh = "bash",
	zsh = "bash",
}

local function fence_lang(ft)
	ft = ft or ""
	if is_c_family(ft) then
		-- Prefer cpp fence for C++-ish variants; otherwise c.
		if ft == "cpp" or ft == "objcpp" or ft == "cuda" then
			return "cpp"
		end
		return "c"
	end
	return FENCE_FT_MAP[ft] or ft
end

-- -------------------------------------------------------------------
-- Prompt builders
-- -------------------------------------------------------------------

local function build_explain_prompt(ft)
	ft = ft or ""

	-- Preserve high-rigor C-family explain prompt.
	if is_c_family(ft) then
		return table.concat({
			"Explain the following snippet step-by-step (C and C++ where relevant).",
			"",
			"Rules:",
			"- First, echo the snippet exactly as you received it in a fenced block labeled: ```received ... ```.",
			"- If the snippet appears incomplete/truncated, say so explicitly before analysis.",
			"- Be strictly accurate about the C/C++ standard rules. If unsure, say so.",
			"- Clearly separate: (A) well-defined behavior, (B) unspecified/indeterminate order, (C) implementation-defined behavior, (D) undefined behavior (UB).",
			"- When discussing arithmetic, be precise about: integer promotions, usual arithmetic conversions, and signed/unsigned mixing.",
			"- Do NOT claim that 'float promotes to double' in ordinary expressions in C. (That's only guaranteed for default argument promotions, e.g., varargs.)",
			"- Do NOT say 'snippet is incomplete/truncated'. Treat it as a standalone snippet and state assumptions explicitly (e.g., assume a and b are int unless shown otherwise).",
			"- Separate compile-time ill-formed/constraint violations from runtime UB. Don't label missing includes as runtime UB; say 'diagnostic required' (C) / 'ill-formed' (C++).",
			"- For C++, be precise: <cstdio> + std::printf (don't imply printf is always in the global namespace).",
			"- Only raise format-string UB if you can name the exact mismatch after default argument promotions.",
			"For sequencing UB, use the canonical language: 'unsequenced modification and value computation/read of the same scalar' (C++) / 'between sequence points, a side effect and an unsequenced read' (C). Don't paraphrase",
			"- For pointer arithmetic, state the valid range (same array object or one-past) and what is UB.",
			"- Keep it concise: maximum 12 bullets. No filler, focused on what applies to THIS snippet.",
			"- Do NOT rewrite the code unless I ask.",
		}, "\n")
	end

	-- Generic explain prompt for non C-family.
	return table.concat({
		string.format("Explain the following %s snippet step-by-step.", (ft ~= "" and ft) or "code"),
		"",
		"Rules:",
		"- First, echo the snippet exactly as you received it in a fenced block labeled: ```received ... ```.",
		"- Be strictly accurate about the language semantics and runtime behavior. If unsure, say so explicitly.",
		"- Focus on what THIS snippet does and why (control flow, data flow, key language features used).",
		"- Call out likely errors, edge cases, and surprising behavior, but don’t invent context not present.",
		"- Keep it concise: maximum 12 bullets.",
		"- Do NOT rewrite the code unless I ask.",
	}, "\n")
end

local function build_apply_prompt(user_instruction, selected_text)
	return table.concat({
		"You are rewriting ONLY the selected text provided below.",
		"",
		"Return ONLY the replacement text BETWEEN these exact markers, and NOTHING else:",
		"<<<BEGIN>>>",
		"(replacement lines)",
		"<<<END>>>",
		"",
		"ABSOLUTE RULES:",
		"- Output must contain BOTH markers, always.",
		"- No explanation, no questions, no advice.",
		"- No markdown fences/backticks in your output.",
		"- Preserve indentation and line breaks.",
		"- Output must be valid code for the same language as the input.",
		"",
		"If you cannot comply, your entire output MUST be exactly:",
		"<<<BEGIN>>>",
		"ERROR",
		"<<<END>>>",
		"",
		"Instruction:",
		user_instruction,
		"",
		"Selected text:",
		"<<<SELECTED>>>",
		selected_text,
		"<<<END_SELECTED>>>",
	}, "\n")
end

local function build_raw_rewrite_prompt(user_instruction, ft, line_count)
	local lc = line_count

	local rules = {
		"You will be given a code snippet below.",
		"Apply my instruction to that snippet.",
		"",
		"ABSOLUTE OUTPUT RULES:",
		"- Output ONLY the rewritten code. No prose. No explanations. No questions.",
		"- No markdown fences/backticks.",
		"- Preserve indentation.",
	}

	if lc then
		table.insert(rules, string.format("- Output must be exactly %d line(s).", lc))
	end

	return table.concat(
		vim.list_extend(rules, {
			"",
			"Instruction:",
			user_instruction,
		}),
		"\n"
	)
end

local function parse_apply_body(raw_lines)
	-- 1) parse markers from raw first (best chance to see markers)
	local body = extract_between_markers(raw_lines, "<<<BEGIN>>>", "<<<END>>>")
	if #body > 0 then
		return body
	end

	-- 2) fallback: try cleaned transcript output in case codex wrapped things oddly
	local cleaned = clean_codex_output(raw_lines)
	body = extract_between_markers(cleaned, "<<<BEGIN>>>", "<<<END>>>")
	return body
end

-- -------------------------------------------------------------------
-- Job runners (THE place to add ui_start/ui_stop)
-- -------------------------------------------------------------------

local function run_codex(input, prompt, callback)
	local out_stdout, out_stderr = {}, {}

	ui_start("Codex working…")

	local job_id = vim.fn.jobstart({ "codex", "exec", "--skip-git-repo-check", prompt }, {
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
					ui_stop("Codex failed (see output)", vim.log.levels.ERROR)
					if #out_stderr > 0 then
						open_scratch(out_stderr, "text", "Codex STDERR")
					end
					return
				end

				ui_stop("Codex done", vim.log.levels.INFO)

				if callback then
					-- NOTE: keep raw for callers that need it; call prefer_clean_answer() at call sites
					callback(out_stdout)
				end
			end)
		end,
	})

	if job_id > 0 then
		if input and input ~= "" then
			vim.fn.chansend(job_id, input .. "\n")
		end
		vim.fn.chanclose(job_id, "stdin")
	else
		ui_stop("Failed to start Codex job", vim.log.levels.ERROR)
	end
end

-- Run codex exec with the INPUT embedded in the prompt (no stdin).
local function run_codex_embedded(input, instruction, callback, ft)
	local out_stdout, out_stderr = {}, {}

	local lang = fence_lang(ft or "c")
	local full_prompt = instruction .. "\n\n---\nHere is the code/snippet:\n```" .. lang .. "\n" .. input .. "\n```"

	ui_start("Codex working…")

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
					ui_stop("Codex failed (see output)", vim.log.levels.ERROR)
					if #out_stderr > 0 then
						open_scratch(out_stderr, "text", "Codex STDERR")
					end
					return
				end

				ui_stop("Codex done", vim.log.levels.INFO)

				local output = (#out_stdout > 0) and out_stdout or out_stderr

				local cleaned = {}
				for _, line in ipairs(output) do
					line = (line or ""):gsub("\r", "")
					if not line:match("^Skipping markdown%-preview build") then
						table.insert(cleaned, line)
					end
				end

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

function M.explain_current_line()
	local line = vim.fn.getline(".")
	local ft = vim.bo.filetype or ""
	local default_prompt = build_explain_prompt(ft)

	prompt_user({ prompt = "Codex explain: ", default = default_prompt }, function(user_prompt)
		run_codex_embedded(line, user_prompt, function(output)
			open_scratch(clean_codex_output(output), "markdown", "Explain Line")
		end, ft)
	end)
end

function M.apply_inline_current_line()
	local line = vim.fn.getline(".")
	local lnum = vim.fn.line(".")
	local want_lines = 1

	prompt_user({ prompt = "Codex instruction (apply): " }, function(user_prompt)
		local out_stdout, out_stderr = {}, {}
		local prompt = build_apply_prompt(user_prompt, line)

		ui_start("Codex working…")

		local job_id = vim.fn.jobstart({ "codex", "exec", "--skip-git-repo-check", prompt }, {
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
					local raw = normalize_lines((#out_stdout > 0) and out_stdout or out_stderr)

					if code ~= 0 then
						ui_stop("Codex failed (see output)", vim.log.levels.ERROR)
						open_scratch(raw, "text", "Codex Apply (failed)")
						return
					end

					ui_stop("Codex done", vim.log.levels.INFO)

					local body = parse_apply_body(raw)

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

					vim.api.nvim_buf_set_lines(0, lnum - 1, lnum, false, body)
				end)
			end,
		})

		if job_id <= 0 then
			ui_stop("Failed to start Codex job", vim.log.levels.ERROR)
		end
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
		return trim_blank_edges(out)
	end

	local default_prompt = table.concat({
		"Generate a unified diff that applies my instruction to the provided snippet.",
		"",
		"ABSOLUTE OUTPUT RULES:",
		"- Output ONLY a unified diff. No prose. No explanations.",
		"- No markdown fences/backticks.",
		"- Use these exact filenames in the headers:",
		"  --- a/selection",
		"  +++ b/selection",
		"- Include at least one hunk header starting with @@.",
	}, "\n")

	prompt_user({ prompt = "Codex instruction (diff): ", default = "" }, function(user_prompt)
		local diff_prompt = table.concat({ default_prompt, "", "Instruction:", user_prompt }, "\n")

		run_codex_embedded(line, diff_prompt, function(output)
			local raw = normalize_lines(output or {})
			local cleaned = clean_codex_output(raw)

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
	local default_prompt = build_explain_prompt(ft)

	prompt_user({ prompt = "Codex explain: ", default = default_prompt }, function(user_prompt)
		run_codex_embedded(text, user_prompt, function(output)
			open_scratch(clean_codex_output(output), "markdown", "Explain Selection")
		end, ft)
	end)
end

function M.explain_selection()
	local text = select(1, collect_selection())
	local ft = vim.bo.filetype or ""
	local default_prompt = build_explain_prompt(ft)

	prompt_user({ prompt = "Codex explain: ", default = default_prompt }, function(user_prompt)
		run_codex_embedded(text, user_prompt, function(output)
			open_scratch(clean_codex_output(output), "markdown", "Explain Selection")
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

	prompt_user({ prompt = "Codex instruction: " }, function(user_prompt)
		local prompt = build_raw_rewrite_prompt(user_prompt, ft, want_lines)

		run_codex_embedded(text, prompt, function(output)
			local body = prefer_clean_answer(output)

			-- Guard: refuse to overwrite selection if Codex ignored the "code only" rules
			local first = vim.trim(body[1] or "")
			local looks_like_chat = first:match("^Happy to help")
				or first:match("^Please paste")
				or first:match("^What text should I")
				or first:match("^Sure")
				or first:match("^I can")

			if looks_like_chat then
				open_scratch(body, "text", "Codex Output (rule break)")
				vim.notify("Codex violated output rules; not applying", vim.log.levels.WARN, { title = "Codex" })
				return
			end

			-- defensive: keep exactly want_lines
			if #body > want_lines then
				body = vim.list_slice(body, 1, want_lines)
			end
			if #body < want_lines then
				open_scratch(body, "text", "Codex Output (wrong line count)")
				vim.notify(
					string.format("Codex returned %d lines, expected %d; not applying", #body, want_lines),
					vim.log.levels.WARN,
					{ title = "Codex" }
				)
				return
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

	prompt_user({ prompt = "Codex instruction: " }, function(user_prompt)
		local prompt = build_raw_rewrite_prompt(user_prompt, ft, nil)
		run_codex_embedded(text, prompt, function(output)
			open_scratch(prefer_clean_answer(output), nil, "Codex Output")
		end, ft)
	end)
end

function M.save_output_to_file_text(text)
	if not text or vim.trim(text) == "" then
		vim.notify("No selection captured", vim.log.levels.WARN, { title = "Codex" })
		return
	end
	local ft = vim.bo.filetype or "text"

	prompt_user({ prompt = "Codex instruction: " }, function(user_prompt)
		prompt_user({ prompt = "Save output as: " }, function(filename)
			local prompt = build_raw_rewrite_prompt(user_prompt, ft, nil)
			run_codex_embedded(text, prompt, function(output)
				local to_write = prefer_clean_answer(output)

				-- Optional safety: refuse to write obvious chatty rule-break output
				local first = vim.trim(to_write[1] or "")
				if first:match("^Happy to help") or first:match("^Please paste") then
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

	prompt_user({ prompt = "Codex instruction (apply): " }, function(user_prompt)
		local out_stdout, out_stderr = {}, {}
		local prompt = build_apply_prompt(user_prompt, text)

		ui_start("Codex working…")

		local job_id = vim.fn.jobstart({ "codex", "exec", "--skip-git-repo-check", prompt }, {
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
					local raw = normalize_lines((#out_stdout > 0) and out_stdout or out_stderr)

					if code ~= 0 then
						ui_stop("Codex failed (see output)", vim.log.levels.ERROR)
						open_scratch(raw, "text", "Codex Apply (failed)")
						return
					end

					ui_stop("Codex done", vim.log.levels.INFO)

					local body = parse_apply_body(raw)

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

					vim.api.nvim_buf_set_lines(0, start_line - 1, end_line, false, body)
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

		return trim_blank_edges(out)
	end

	local default_prompt = table.concat({
		"Generate a unified diff that applies my instruction to the provided snippet.",
		"",
		"ABSOLUTE OUTPUT RULES:",
		"- Output ONLY a unified diff. No prose. No explanations.",
		"- No markdown fences/backticks.",
		"- Use these exact filenames in the headers:",
		"  --- a/selection",
		"  +++ b/selection",
		"- Include at least one hunk header starting with @@.",
	}, "\n")

	prompt_user({ prompt = "Codex instruction (diff): ", default = "" }, function(user_prompt)
		local diff_prompt = table.concat({
			default_prompt,
			"",
			"Instruction:",
			user_prompt,
		}, "\n")

		local ft = vim.bo.filetype or ""

		run_codex_embedded(selected, diff_prompt, function(output)
			local raw = normalize_lines(output or {})
			local cleaned = clean_codex_output(raw)

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

	prompt_user({ prompt = "Codex instruction: " }, function(user_prompt)
		local prompt = build_raw_rewrite_prompt(user_prompt, ft, 1)
		run_codex_embedded(line, prompt, function(output)
			local body = prefer_clean_answer(output)

			local first = vim.trim(body[1] or "")
			if first:match("^Happy to help") or first:match("^Please paste") then
				open_scratch(body, "text", "Codex Output (rule break)")
				vim.notify("Codex violated output rules; not applying", vim.log.levels.WARN, { title = "Codex" })
				return
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

	prompt_user({ prompt = "Codex instruction: " }, function(user_prompt)
		local prompt = table.concat({
			"You will be given an entire file below.",
			"Apply my instruction to it.",
			"",
			"ABSOLUTE OUTPUT RULES:",
			"- Output ONLY the full rewritten file contents. No prose. No patch format. No approvals talk.",
			"- No markdown fences/backticks.",
			"- Preserve content you are not changing.",
			"",
			"Instruction:",
			user_prompt,
		}, "\n")

		run_codex_embedded(text, prompt, function(output)
			local body = prefer_clean_answer(output)

			-- Safety valve: if output looks like prose, don't overwrite; show scratch instead.
			local first = vim.trim(body[1] or "")
			if
				first:match("^I attempted")
				or first:match("^Confirm")
				or first:match("^Proposed change")
				or first:match("^Happy to help")
				or first:match("^Please paste")
			then
				open_scratch(body, "text", "Codex File Output (refused overwrite)")
				vim.notify(
					"Codex returned non-file output; not overwriting buffer",
					vim.log.levels.WARN,
					{ title = "Codex" }
				)
				return
			end

			vim.api.nvim_buf_set_lines(0, 0, -1, false, body)
		end, ft)
	end)
end

function M.patch_buffer()
	local filename = vim.fn.expand("%:p")
	prompt_user({ prompt = "Codex patch: " }, function(prompt)
		local cmd = string.format("codex --diff %q %q", prompt, filename)
		vim.cmd("botright split | term " .. cmd)
	end)
end

function M.scratchpad_prompt(default_prompt)
	prompt_user({ prompt = "Codex scratch: ", default = default_prompt or "" }, function(prompt)
		local text = vim.api.nvim_buf_get_lines(0, 0, -1, false)
		local buftext = table.concat(text, "\n")
		local ft = vim.bo.filetype or ""

		run_codex_embedded(buftext, prompt, function(output)
			open_scratch(clean_codex_output(output), "markdown")
		end, ft)
	end)
end

return M
