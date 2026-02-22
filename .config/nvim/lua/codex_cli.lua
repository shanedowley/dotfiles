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
		vim.fn.chansend(job_id, input .. "\n")
		vim.fn.chanclose(job_id, "stdin")
	else
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
	vim.ui.input(opts, function(answer)
		if answer and answer ~= "" then
			cb(answer)
		end
	end)
end

local function open_scratch(lines, filetype)
	vim.cmd("new")
	vim.api.nvim_buf_set_lines(0, 0, -1, false, lines or {})
	vim.bo.buftype = "nofile"
	vim.bo.bufhidden = "wipe"
	vim.bo.swapfile = false
	if filetype then
		vim.bo.filetype = filetype
	end
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

function M.scratchpad_prompt()
	prompt_user({ prompt = "Codex scratch: " }, function(prompt)
		local cmd = "codex " .. vim.fn.shellescape(prompt)
		vim.fn.jobstart(cmd, {
			stdout_buffered = true,
			on_stdout = function(_, data)
				if data then
					open_scratch(data, nil)
				end
			end,
			on_stderr = function(_, data)
				if data and #data > 0 then
					vim.notify(table.concat(data, "\n"), vim.log.levels.ERROR, { title = "Codex" })
				end
			end,
		})
	end)
end

return M
