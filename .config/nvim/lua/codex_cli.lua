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
	local output = {}

	local full_prompt = instruction .. "\n\n---\nHere is the code/snippet:\n```c\n" .. input .. "\n```"

	-- tiny “pulse” while Codex runs
	local done = false
	vim.notify("Codex: thinking…", vim.log.levels.INFO, { title = "Codex" })
	local timer = vim.loop.new_timer()
	if timer then
		timer:start(
			1200,
			1200,
			vim.schedule_wrap(function()
				if done then
					timer:stop()
					timer:close()
					return
				end
				-- re-pulse without spamming too hard
				vim.notify("Codex: still working…", vim.log.levels.INFO, { title = "Codex" })
			end)
		)
	end

	local job_id = vim.fn.jobstart({ "codex", "exec", "--skip-git-repo-check", full_prompt }, {
		pty = true, -- IMPORTANT: makes Codex think it has a terminal
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
				vim.list_extend(output, data)
			end
		end,

		-- IMPORTANT: do NOT notify on stderr; capture it (Codex writes a lot here)
		stderr_buffered = true,
		on_stderr = function(_, data)
			if data then
				vim.list_extend(output, data)
			end
		end,

		on_exit = function(_, code)
			done = true
			if code == 0 and callback then
				local cleaned = {}
				for _, line in ipairs(output) do
					line = line:gsub("\r", "")
					if not line:match("^Skipping markdown%-preview build") then
						table.insert(cleaned, line)
					end
				end
				output = cleaned

				callback(output)
			else
				vim.notify("Codex exited with code " .. tostring(code), vim.log.levels.WARN, { title = "Codex" })
			end
		end,
	})

	if job_id <= 0 then
		done = true
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
-- Codex CLI prints a transcript, then a line exactly "codex", then the answer.
local function clean_codex_output(lines)
	local out = {}
	local capture = false

	for _, line in ipairs(lines or {}) do
		if line == nil then
			goto continue
		end

		-- Start capturing ONLY after the transcript marker.
		if line == "codex" then
			capture = true
			goto continue
		end

		if not capture then
			goto continue
		end

		-- Drop common tail noise
		if line:match("^tokens used") then
			goto continue
		end
		if line:match("^Press ENTER") then
			goto continue
		end
		if line:match("^Skipping markdown%-preview build") then
			goto continue
		end

		table.insert(out, line)

		::continue::
	end

	-- If we never saw "codex", fall back to original lines (better than blank).
	if #out == 0 then
		return lines or {}
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
		local added = line:match("^%+(.*)")
		if added then
			table.insert(new_lines, added)
		end
	end
	return new_lines
end

-- -------------------------------------------------------------------
-- Public API (call these from Lazy "keys" mappings)
-- -------------------------------------------------------------------

-- Explain the current Visual selection (C learning helper)
function M.explain_selection()
	local text = select(1, collect_selection())

	local default_prompt = "Explain what this code does step-by-step as C (not C++). "
		.. "Call out undefined behavior, lifetime issues, and common beginner mistakes. "
		.. "Do NOT rewrite it unless I ask."

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
				-- Use fnameescape to avoid issues with spaces/special chars
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
				-- Try to clean/normalize a diff from output
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

				-- Apply patch mapping inside the diff scratch
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
