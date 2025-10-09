local M = {}

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
				vim.notify("Codex exited with code " .. code, vim.log.levels.WARN, { title = "Codex" })
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

function M.setup()
	local map = vim.keymap.set

	-- Visual selection → replace
	map("v", "<leader>cc", function()
		local text, start_line, end_line = collect_selection()
		prompt_user({ prompt = "Codex instruction: " }, function(user_prompt)
			run_codex(text, user_prompt, function(output)
				vim.api.nvim_buf_set_lines(0, start_line - 1, end_line, false, output)
			end)
		end)
	end, { desc = "Codex: replace selection", silent = true })

	-- Visual selection → open in scratch buffer
	map("v", "<leader>co", function()
		local text = collect_selection()
		prompt_user({ prompt = "Codex instruction: " }, function(user_prompt)
			run_codex(text, user_prompt, function(output)
				vim.cmd("new")
				vim.api.nvim_buf_set_lines(0, 0, -1, false, output)
				vim.bo.buftype = "nofile"
				vim.bo.bufhidden = "wipe"
				vim.bo.swapfile = false
			end)
		end)
	end, { desc = "Codex: open output in scratch buffer", silent = true })

	-- Visual selection → save to file
	map("v", "<leader>cs", function()
		local text = collect_selection()
		prompt_user({ prompt = "Codex instruction: " }, function(user_prompt)
			prompt_user({ prompt = "Save output as: " }, function(filename)
				run_codex(text, user_prompt, function(output)
					vim.cmd("edit " .. filename)
					vim.api.nvim_buf_set_lines(0, 0, -1, false, output)
					vim.cmd.write()
					vim.notify("Codex output written to " .. filename, vim.log.levels.INFO, { title = "Codex" })
				end)
			end)
		end)
	end, { desc = "Codex: save output to file", silent = true })

	-- Visual selection → apply diff or inline
	map("v", "<leader>ca", function()
		local text, start_line, end_line = collect_selection()
		prompt_user({ prompt = "Codex instruction (apply): " }, function(user_prompt)
			run_codex(text, user_prompt, function(output)
				if not output or #output == 0 then
					vim.notify("Codex returned no output", vim.log.levels.WARN, { title = "Codex" })
					return
				end

				local is_diff = false
				for _, line in ipairs(output) do
					if line:match("^@@") or line:match("^%-%-%-") or line:match("^%+%+%+") then
						is_diff = true
						break
					end
				end

				if is_diff then
					local new_lines = {}
					for _, line in ipairs(output) do
						local added = line:match("^%+(.*)")
						if added then
							table.insert(new_lines, added)
						end
					end
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
	end, { desc = "Codex: apply inline", silent = true })

	-- Visual selection → diff preview
	map("v", "<leader>cd", function()
		local text = collect_selection()
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
					local inside_diff = false
					for _, line in ipairs(diff_output) do
						if line:match("^```") then
							inside_diff = not inside_diff
						elseif inside_diff or line:match("^---") or line:match("^+++") or line:match("^[@%+%-]") then
							table.insert(cleaned, line)
						end
					end

					if #cleaned == 0 then
						vim.notify("No valid diff found in Codex output", vim.log.levels.WARN, { title = "Codex" })
						return
					end

					vim.cmd("new")
					vim.api.nvim_buf_set_lines(0, 0, -1, false, cleaned)
					vim.bo.buftype = "nofile"
					vim.bo.bufhidden = "wipe"
					vim.bo.swapfile = false
					vim.bo.filetype = "diff"

					vim.api.nvim_buf_set_keymap(
						0,
						"n",
						"<leader>ca",
						":w! /tmp/codex_patch.diff | !git apply /tmp/codex_patch.diff<CR>",
						{ noremap = true, silent = true, desc = "Apply Codex patch" }
					)

					print("Diff ready. Press <leader>ca to apply.")
				end,
			})

			if job_id > 0 then
				vim.fn.chansend(job_id, text .. "\n")
				vim.fn.chanclose(job_id, "stdin")
			else
				print("Failed to start Codex job")
			end
		end)
	end, { desc = "Codex: preview diff", silent = true })

	-- Normal mode helpers
	map("n", "<leader>cl", function()
		local line = vim.fn.getline(".")
		prompt_user({ prompt = "Codex instruction: " }, function(user_prompt)
			run_codex(line, user_prompt, function(output)
				vim.api.nvim_buf_set_lines(0, vim.fn.line(".") - 1, vim.fn.line("."), false, output)
			end)
		end)
	end, { desc = "Codex: run on current line", silent = true })

	map("n", "<leader>cf", function()
		local buf = vim.api.nvim_buf_get_lines(0, 0, -1, false)
		local text = table.concat(buf, "\n")
		prompt_user({ prompt = "Codex instruction: " }, function(user_prompt)
			run_codex(text, user_prompt, function(output)
				vim.api.nvim_buf_set_lines(0, 0, -1, false, output)
			end)
		end)
	end, { desc = "Codex: run on entire file", silent = true })

	map("n", "<leader>cp", function()
		local filename = vim.fn.expand("%:p")
		prompt_user({ prompt = "Codex patch: " }, function(prompt)
			local cmd = string.format("codex --diff %q %q", prompt, filename)
			vim.cmd("botright split | term " .. cmd)
		end)
	end, { desc = "Codex: patch buffer", silent = true })

	map("n", "<leader>cs", function()
		prompt_user({ prompt = "Codex scratch: " }, function(prompt)
			local cmd = "codex " .. vim.fn.shellescape(prompt)
			vim.fn.jobstart(cmd, {
				stdout_buffered = true,
				on_stdout = function(_, data)
					if data then
						vim.cmd("new")
						vim.api.nvim_buf_set_lines(0, 0, -1, false, data)
					end
				end,
			})
		end)
	end, { desc = "Codex: scratchpad", silent = true })

	local ok_wk, wk = pcall(require, "which-key")
	if ok_wk then
		wk.add({
			{ "<leader>c", group = "Codex" },
			{ "<leader>cc", desc = "Run on selection" },
			{ "<leader>co", desc = "Open output in scratch buffer" },
			{ "<leader>cs", desc = "Scratchpad prompt" },
			{ "<leader>cp", desc = "Patch buffer" },
			{ "<leader>cl", desc = "Run on current line" },
			{ "<leader>cf", desc = "Run on entire file" },
			{ "<leader>ca", desc = "Apply inline" },
			{ "<leader>cd", desc = "Preview diff" },
		})
	end
end

return M
