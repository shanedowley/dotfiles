local map = vim.keymap.set
local ok, wk = pcall(require, "which-key")
if ok then
	wk.register({
		e = "Explorer",
		f = { name = "Find", f = "Files", g = "Grep", b = "Buffers", h = "Help" },
		s = { name = "Session", l = "Load Last", r = "Load CWD", s = "Save", d = "Stop Autosave" },
		d = { name = "Debug", u = "Toggle UI", x = "Terminate", r = "Restart" },
		t = { name = "Tabs" },
		w = "Write",
		q = "Quit",
	}, { prefix = "<leader>" })
end
local opts = { noremap = true, silent = true }

-- =========================
-- General Keymaps
-- =========================
local map = vim.keymap.set
local opts = { noremap = true, silent = true }

-- Leader set in init.lua
map("n", "<leader>w", "<cmd>w<cr>", { desc = "Save file" })
map("n", "<leader>q", "<cmd>q<cr>", { desc = "Quit" })

map("n", "<leader>e", ":NvimTreeToggle<CR>", opts)

map("n", "<leader>ff", "<cmd>Telescope find_files<cr>", opts)
map("n", "<leader>fg", "<cmd>Telescope live_grep<cr>", opts)
map("n", "<leader>fb", "<cmd>Telescope buffers<cr>", opts)
map("n", "<leader>fh", "<cmd>Telescope help_tags<cr>", opts)

-- Move lines up/down with Alt-j/k
map("n", "<A-j>", ":m .+1<CR>==", opts)
map("n", "<A-k>", ":m .-2<CR>==", opts)
map("i", "<A-j>", "<Esc>:m .+1<CR>==gi", opts)
map("i", "<A-k>", "<Esc>:m .-2<CR>==gi", opts)
map("v", "<A-j>", ":m '>+1<CR>gv=gv", opts)
map("v", "<A-k>", ":m '<-2<CR>gv=gv", opts)

-- DAP KEYMAPS
map("n", "<F5>", ":DapContinue<CR>", opts)
map("n", "<F10>", ":DapStepOver<CR>", opts)
map("n", "<F11>", ":DapStepInto<CR>", opts)
map("n", "<F12>", ":DapStepOut<CR>", opts)
map("n", "<leader>b", ":DapToggleBreakpoint<CR>", opts)
map("n", "<leader>B", function()
	vim.fn.input("Breakpoint condition: ", "", "expression")
end, opts)
map("n", "<leader>dr", ":DapRestartFrame<CR>", opts)
map("n", "<leader>dx", ":DapTerminate<CR>", opts)

-- Toggle DAP UI
map("n", "<leader>du", function()
	require("dapui").toggle()
end, opts)

-- =========================
-- Pane Navigation
-- =========================
vim.keymap.set("n", "<leader>h", "<C-w>h", { desc = "Move to left pane" })
vim.keymap.set("n", "<leader>l", "<C-w>l", { desc = "Move to right pane" })
vim.keymap.set("n", "<leader>j", "<C-w>j", { desc = "Move to lower pane" })
vim.keymap.set("n", "<leader>k", "<C-w>k", { desc = "Move to upper pane" })

-- =========================
-- Pane Resizing
-- =========================
vim.keymap.set("n", "<leader><Up>", ":resize -2<CR>", { desc = "Shrink pane height" })
vim.keymap.set("n", "<leader><Down>", ":resize +2<CR>", { desc = "Grow pane height" })
vim.keymap.set("n", "<leader><Left>", ":vertical resize -2<CR>", { desc = "Shrink pane width" })
vim.keymap.set("n", "<leader><Right>", ":vertical resize +2<CR>", { desc = "Grow pane width" })

-- Open current file in default browser (macOS)
vim.keymap.set("n", "<leader>bp", ":!open -a safari.app %<CR>", { desc = "Browser Preview" })

-- =========================
-- Codex Integration
-- =========================
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
				vim.notify(table.concat(data, "\n"), vim.log.levels.ERROR)
			end
		end,
		on_exit = function(_, code)
			if code == 0 and callback then
				callback(output)
			else
				vim.notify("Codex exited with code " .. code, vim.log.levels.WARN)
			end
		end,
	})

	if job_id > 0 then
		vim.fn.chansend(job_id, input .. "\n")
		vim.fn.chanclose(job_id, "stdin")
	else
		vim.notify("Failed to start Codex job", vim.log.levels.ERROR)
	end
end

-- Visual: replace selection with Codex output
map("v", "<leader>cc", function()
	local start_pos = vim.fn.getpos("'<")
	local end_pos = vim.fn.getpos("'>")
	local lines = vim.fn.getline(start_pos[2], end_pos[2])
	local text = table.concat(lines, "\n")

	vim.ui.input({ prompt = "Codex instruction: " }, function(user_prompt)
		if not user_prompt or user_prompt == "" then
			return
		end
		run_codex(text, user_prompt, function(output)
			vim.api.nvim_buf_set_lines(0, start_pos[2] - 1, end_pos[2], false, output)
		end)
	end)
end, { desc = "Codex: replace selection" })

-- Visual: open Codex output in scratch buffer
map("v", "<leader>co", function()
	local start_pos = vim.fn.getpos("'<")
	local end_pos = vim.fn.getpos("'>")
	local lines = vim.fn.getline(start_pos[2], end_pos[2])
	local text = table.concat(lines, "\n")

	vim.ui.input({ prompt = "Codex instruction: " }, function(user_prompt)
		if not user_prompt or user_prompt == "" then
			return
		end
		run_codex(text, user_prompt, function(output)
			vim.cmd("new")
			vim.api.nvim_buf_set_lines(0, 0, -1, false, output)
			vim.bo.buftype = "nofile"
			vim.bo.bufhidden = "wipe"
			vim.bo.swapfile = false
		end)
	end)
end, { desc = "Codex: open output in scratch buffer" })

-- Visual: save Codex output directly to file
map("v", "<leader>cs", function()
	local start_pos = vim.fn.getpos("'<")
	local end_pos = vim.fn.getpos("'>")
	local lines = vim.fn.getline(start_pos[2], end_pos[2])
	local text = table.concat(lines, "\n")

	vim.ui.input({ prompt = "Codex instruction: " }, function(user_prompt)
		if not user_prompt or user_prompt == "" then
			return
		end
		vim.ui.input({ prompt = "Save output as: " }, function(filename)
			if not filename or filename == "" then
				return
			end
			run_codex(text, user_prompt, function(output)
				vim.cmd("edit " .. filename)
				vim.api.nvim_buf_set_lines(0, 0, -1, false, output)
				vim.cmd("w")
				print("Codex output written to " .. filename)
			end)
		end)
	end)
end, { desc = "Codex: save output to new file" })

-- Visual: apply Codex changes directly to buffer (auto-apply diff/code)
vim.keymap.set("v", "<leader>ca", function()
	local start_pos = vim.fn.getpos("'<")
	local end_pos = vim.fn.getpos("'>")
	local start_line, end_line = start_pos[2], end_pos[2]

	-- normalize selection
	if start_line > end_line then
		start_line, end_line = end_line, start_line
	end

	local lines = vim.fn.getline(start_line, end_line)
	if not lines or #lines == 0 then
		vim.notify("No lines selected", vim.log.levels.WARN)
		return
	end
	local text = table.concat(lines, "\n")

	vim.ui.input({ prompt = "Codex instruction (apply): " }, function(user_prompt)
		if not user_prompt or user_prompt == "" then
			return
		end

		run_codex(text, user_prompt, function(output)
			if not output or #output == 0 then
				vim.notify("Codex returned no output", vim.log.levels.WARN)
				return
			end

			-- detect if Codex returned a diff
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
					vim.notify("Codex diff applied inline!", vim.log.levels.INFO)
				else
					vim.notify("Codex diff contained no additions", vim.log.levels.WARN)
				end
			else
				if #output > 0 then
					vim.api.nvim_buf_set_lines(0, start_line - 1, end_line, false, output)
					vim.notify("Codex output applied inline!", vim.log.levels.INFO)
				else
					vim.notify("Codex output was empty", vim.log.levels.WARN)
				end
			end
		end)
	end)
end, { desc = "Codex: auto-apply to buffer" })

-- Normal: run Codex on current line
map("n", "<leader>cl", function()
	local line = vim.fn.getline(".")
	vim.ui.input({ prompt = "Codex instruction: " }, function(user_prompt)
		if not user_prompt or user_prompt == "" then
			return
		end
		run_codex(line, user_prompt, function(output)
			vim.api.nvim_buf_set_lines(0, vim.fn.line(".") - 1, vim.fn.line("."), false, output)
		end)
	end)
end, { desc = "Codex: run on current line" })

-- Normal: run Codex on entire file
map("n", "<leader>cf", function()
	local buf = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	local text = table.concat(buf, "\n")
	vim.ui.input({ prompt = "Codex instruction: " }, function(user_prompt)
		if not user_prompt or user_prompt == "" then
			return
		end
		run_codex(text, user_prompt, function(output)
			vim.api.nvim_buf_set_lines(0, 0, -1, false, output)
		end)
	end)
end, { desc = "Codex: run on entire file" })

-- Visual: Codex diff preview + apply option
-- Visual: Codex diff preview + apply option (cleaned diff only)
vim.keymap.set("v", "<leader>cd", function()
	local start_pos = vim.fn.getpos("'<")
	local end_pos = vim.fn.getpos("'>")
	local lines = vim.fn.getline(start_pos[2], end_pos[2])
	local text = table.concat(lines, "\n")

	vim.ui.input({ prompt = "Codex instruction (diff): " }, function(user_prompt)
		if not user_prompt or user_prompt == "" then
			return
		end

		local diff_output = {}

		local job_id = vim.fn.jobstart({ "codex", "exec", "--skip-git-repo-check", user_prompt }, {
			stdout_buffered = true,
			on_stdout = function(_, data)
				if data then
					vim.list_extend(diff_output, data)
				end
			end,
			on_exit = function()
				-- Extract only lines starting with diff markers
				local cleaned = {}
				local inside_diff = false
				for _, line in ipairs(diff_output) do
					if line:match("^```") then
						-- toggle diff block markers off/on
						inside_diff = not inside_diff
					elseif inside_diff or line:match("^---") or line:match("^+++") or line:match("^[@%+%-]") then
						table.insert(cleaned, line)
					end
				end

				if #cleaned == 0 then
					vim.notify("No valid diff found in Codex output", vim.log.levels.WARN)
					return
				end

				-- Open diff in buffer
				vim.cmd("new")
				vim.api.nvim_buf_set_lines(0, 0, -1, false, cleaned)
				vim.bo.buftype = "nofile"
				vim.bo.bufhidden = "wipe"
				vim.bo.swapfile = false
				vim.bo.filetype = "diff"

				-- Apply shortcut
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
end, { desc = "Codex: preview diff" })
