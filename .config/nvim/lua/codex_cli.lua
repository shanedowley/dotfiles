-- ~/.config/nvim/lua/codex_cli.lua
local M = {}

-- -------------------------------------------------------------------
-- Helpers
-- -------------------------------------------------------------------

local function run_codex(input, prompt, callback)
	local output = {}

	local job_id = vim.fn.jobstart({ "codex", "exec", "--skip-git-repo-check", prompt }, {
		stdout_buffered = true,
		on_stdout = function(_, data)
			if data then
				vim.list_extend(output, data)
			end
		end,
		stderr_buffered = true,
		on_stderr = function(_, data)
			if data and #data > 0 then
				vim.notify(table.concat(data, "\n"), vim.log.levels.ERROR, { title = "Codex" })
			end
		end,
		on_exit = function(_, code)
			if code == 0 and callback then
				callback(output)
			else
				vim.notify("Codex exited with code " .. tostring(code), vim.log.levels.WARN, { title = "Codex" })
			end
		end,
	})

	if job_id > 0 then
		if input and input ~= "" then
			vim.fn.chansend(job_id, input .. "\n")
		end
		vim.fn.chanclose(job_id, "stdin")
	else
		vim.notify("Failed to start Codex job", vim.log.levels.ERROR, { title = "Codex" })
	end
end

-- Run codex exec with the INPUT embedded in the prompt (no stdin).
local function run_codex_embedded(input, instruction, callback)
	local out_stdout, out_stderr = {}, {}

	local full_prompt = instruction .. "\n\n---\nHere is the code/snippet:\n```c\n" .. input .. "\n```"

	-- non-blocking pulse using vim.notify (updates same message)
	local done = false
	local notify_id = nil

	local function pulse(msg)
		notify_id = vim.notify(msg, vim.log.levels.INFO, {
			title = "Codex",
			replace = notify_id,
		})
	end

	pulse("Codex thinking…")

	local uv = vim.uv or vim.loop
	local timer = uv.new_timer()

	local function stop_timer()
		if timer then
			pcall(timer.stop, timer)
			pcall(timer.close, timer)
			timer = nil
		end
	end

	if timer then
		timer:start(
			1200,
			1200,
			vim.schedule_wrap(function()
				if done then
					stop_timer()
					return
				end
				pulse("Codex still working…")
			end)
		)
	end

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
			done = true
			stop_timer()

			if notify_id then
				vim.notify("Done ✓", vim.log.levels.INFO, { title = "Codex", replace = notify_id })
			end

			if code ~= 0 then
				vim.notify("Codex exited with code " .. tostring(code), vim.log.levels.WARN, { title = "Codex" })
				return
			end

			-- Prefer stdout; fall back to stderr if stdout is empty
			local output = (#out_stdout > 0) and out_stdout or out_stderr

			-- Normalize CRLF + drop known noise early
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
		end,
	})

	if job_id <= 0 then
		done = true
		stop_timer()

		vim.notify("Failed to start Codex job", vim.log.levels.ERROR, { title = "Codex" })
	end
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

local function prompt_user(opts, cb)
	vim.ui.input({ prompt = opts.prompt, default = opts.default }, function(answer)
		if answer and answer ~= "" then
			cb(answer)
		end
	end)
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
	-- (This matches the symptom you pasted.)
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

local function output_looks_like_diff(output)
	for _, line in ipairs(output or {}) do
		if line:match("^@@") or line:match("^%-%-%-") or line:match("^%+%+%+") then
			return true
		end
	end
	return false
end

local function extract_added_lines_from_unified_diff(output)
	local new_lines = {}

	for _, line in ipairs(output or {}) do
		-- Skip diff metadata
		if line:match("^%+%+%+") then
			goto continue
		end
		if line:match("^%-%-%-") then
			goto continue
		end
		if line:match("^@@") then
			goto continue
		end

		-- Match real added lines (single leading +)
		local added = line:match("^%+([^+].*)")
		if added then
			table.insert(new_lines, added)
		end

		::continue::
	end

	return new_lines
end

-- -------------------------------------------------------------------
-- Public API
-- -------------------------------------------------------------------

function M.explain_text(text)
	local default_prompt = table.concat({
		"Explain the following snippet step-by-step (C and C++ where relevant).",
		"",
		"Rules:",
		"- First, echo the snippet exactly as you received it in a fenced block labeled: ```received ... ```.",
		"- If the snippet appears incomplete/truncated, say so explicitly before analysis.",
		"- Be strictly accurate about the C/C++ standard rules. If unsure, say so.",
		"- Clearly separate: (A) well-defined behavior, (B) unspecified/indeterminate order, (C) implementation-defined behavior, (D) undefined behavior (UB).",
		"- When discussing arithmetic, be precise about: integer promotions, usual arithmetic conversions, and signed/unsigned mixing.",
		"- Do NOT claim that 'float promotes to double' in ordinary expressions in C. (That’s only guaranteed for default argument promotions, e.g., varargs.)",
		"- For pointer arithmetic, state the valid range (same array object or one-past) and what is UB.",
		"- Keep it concise: maximum 12 bullets. No filler, focused on what applies to THIS snippet.",
		"- Do NOT rewrite the code unless I ask.",
	}, "\n")

	prompt_user({ prompt = "Codex explain: ", default = default_prompt }, function(user_prompt)
		run_codex_embedded(text, user_prompt, function(output)
			open_scratch(clean_codex_output(output), "markdown", "Explain Selection")
		end)
	end)
end

function M.explain_selection()
	local text = select(1, collect_selection())

	local default_prompt = table.concat({
		"Explain the following snippet step-by-step (C and C++ where relevant).",
		"",
		"Rules:",
		"- First, echo the snippet exactly as you received it in a fenced block labeled: ```received ... ```.",
		"- If the snippet appears incomplete/truncated, say so explicitly before analysis.",
		"- Be strictly accurate about the C/C++ standard rules. If unsure, say so.",
		"- Clearly separate: (A) well-defined behavior, (B) unspecified/indeterminate order, (C) implementation-defined behavior, (D) undefined behavior (UB).",
		"- When discussing arithmetic, be precise about: integer promotions, usual arithmetic conversions, and signed/unsigned mixing.",
		"- Do NOT claim that 'float promotes to double' in ordinary expressions in C. (That’s only guaranteed for default argument promotions, e.g., varargs.)",
		"- For pointer arithmetic, state the valid range (same array object or one-past) and what is UB.",
		"- Keep it concise: maximum 12 bullets. No filler, focused on what applies to THIS snippet.",
		"- Do NOT rewrite the code unless I ask.",
	}, "\n")

	prompt_user({ prompt = "Codex explain: ", default = default_prompt }, function(user_prompt)
		run_codex_embedded(text, user_prompt, function(output)
			open_scratch(clean_codex_output(output), "markdown", "Explain Selection")
		end)
	end)
end

function M.replace_selection()
	local text, start_line, end_line = collect_selection()
	prompt_user({ prompt = "Codex instruction: " }, function(user_prompt)
		run_codex(text, user_prompt, function(output)
			vim.api.nvim_buf_set_lines(0, start_line - 1, end_line, false, output)
		end)
	end)
end

function M.open_output_scratch()
	local text = select(1, collect_selection())
	prompt_user({ prompt = "Codex instruction: " }, function(user_prompt)
		run_codex(text, user_prompt, function(output)
			open_scratch(output, nil)
		end)
	end)
end

function M.save_output_to_file()
	local text = select(1, collect_selection())
	prompt_user({ prompt = "Codex instruction: " }, function(user_prompt)
		prompt_user({ prompt = "Save output as: " }, function(filename)
			run_codex(text, user_prompt, function(output)
				vim.cmd("edit " .. vim.fn.fnameescape(filename))
				vim.api.nvim_buf_set_lines(0, 0, -1, false, output)
				vim.cmd("write")
				vim.notify("Codex output written to " .. filename, vim.log.levels.INFO, { title = "Codex" })
			end)
		end)
	end)
end

function M.apply_inline()
	local text, start_line, end_line = collect_selection()
	prompt_user({ prompt = "Codex instruction (apply): " }, function(user_prompt)
		run_codex(text, user_prompt, function(output)
			if not output or #output == 0 then
				vim.notify("Codex returned no output", vim.log.levels.WARN, { title = "Codex" })
				return
			end

			if output_looks_like_diff(output) then
				local new_lines = extract_added_lines_from_unified_diff(output)
				if #new_lines > 0 then
					vim.api.nvim_buf_set_lines(0, start_line - 1, end_line, false, new_lines)
					vim.notify("Codex diff applied inline!", vim.log.levels.INFO, { title = "Codex" })
				else
					vim.notify("Codex diff contained no additions", vim.log.levels.WARN, { title = "Codex" })
				end
			else
				vim.api.nvim_buf_set_lines(0, start_line - 1, end_line, false, output)
				vim.notify("Codex output applied inline!", vim.log.levels.INFO, { title = "Codex" })
			end
		end)
	end)
end

function M.preview_diff()
	local text = select(1, collect_selection())
	prompt_user({ prompt = "Codex instruction (diff): " }, function(user_prompt)
		local diff_output = {}

		local job_id = vim.fn.jobstart({ "codex", "exec", "--skip-git-repo-check", user_prompt }, {
			stdout_buffered = true,
			on_stdout = function(_, data)
				if data then
					vim.list_extend(diff_output, data)
				end
			end,
			on_exit = function()
				local cleaned = {}
				local inside_fence = false
				for _, line in ipairs(diff_output) do
					if line:match("^```") then
						inside_fence = not inside_fence
					elseif inside_fence or line:match("^---") or line:match("^%+%+%+") or line:match("^[@%+%-]") then
						table.insert(cleaned, line)
					end
				end

				if #cleaned == 0 then
					vim.notify("No valid diff found in Codex output", vim.log.levels.WARN, { title = "Codex" })
					return
				end

				open_scratch(cleaned, "diff")

				vim.keymap.set("n", "<leader>ca", function()
					local path = "/tmp/codex_patch.diff"
					vim.cmd("write! " .. path)
					vim.fn.jobstart({ "git", "apply", path }, {
						on_exit = function(_, code)
							if code == 0 then
								vim.notify("Patch applied: " .. path, vim.log.levels.INFO, { title = "Codex" })
							else
								vim.notify(
									"git apply failed (see :messages)",
									vim.log.levels.ERROR,
									{ title = "Codex" }
								)
							end
						end,
					})
				end, { buffer = true, desc = "Apply Codex patch", silent = true })

				vim.notify("Diff ready. Press <leader>ca to apply.", vim.log.levels.INFO, { title = "Codex" })
			end,
		})

		if job_id > 0 then
			vim.fn.chansend(job_id, text .. "\n")
			vim.fn.chanclose(job_id, "stdin")
		else
			vim.notify("Failed to start Codex job", vim.log.levels.ERROR, { title = "Codex" })
		end
	end)
end

function M.run_current_line()
	local line = vim.fn.getline(".")
	prompt_user({ prompt = "Codex instruction: " }, function(user_prompt)
		run_codex(line, user_prompt, function(output)
			local lnum = vim.fn.line(".")
			vim.api.nvim_buf_set_lines(0, lnum - 1, lnum, false, output)
		end)
	end)
end

function M.run_entire_file()
	local buf = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	local text = table.concat(buf, "\n")
	prompt_user({ prompt = "Codex instruction: " }, function(user_prompt)
		run_codex(text, user_prompt, function(output)
			vim.api.nvim_buf_set_lines(0, 0, -1, false, output)
		end)
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

		run_codex_embedded(buftext, prompt, function(output)
			open_scratch(clean_codex_output(output), "markdown")
		end)
	end)
end

return M
