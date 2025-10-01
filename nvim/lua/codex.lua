-- ~/.config/nvim/lua/codex.lua
local M = {}

function M.setup()
	-- Utility: run a shell command and capture output into a new buffer
	local function run_in_split(cmd)
		vim.fn.jobstart(cmd, {
			stdout_buffered = true,
			on_stdout = function(_, data)
				if data then
					vim.cmd("new") -- open a scratch split
					vim.api.nvim_buf_set_lines(0, 0, -1, false, data)
				end
			end,
		})
	end

	-- Selection → Codex
	vim.keymap.set("v", "<leader>cc", function()
		local start_row, start_col = unpack(vim.api.nvim_buf_get_mark(0, "<"))
		local end_row, end_col = unpack(vim.api.nvim_buf_get_mark(0, ">"))
		local lines = vim.api.nvim_buf_get_text(0, start_row - 1, start_col, end_row - 1, end_col + 1, {})
		local text = table.concat(lines, "\n")

		vim.ui.input({ prompt = "Codex prompt: " }, function(prompt)
			if prompt then
				local cmd = string.format("echo %q | codex %q", text, prompt)
				run_in_split(cmd)
			end
		end)
	end, { desc = "Codex on selection" })

	-- Patch file with Codex (diff style)
	vim.keymap.set("n", "<leader>cp", function()
		local filename = vim.fn.expand("%:p")
		vim.ui.input({ prompt = "Codex patch: " }, function(prompt)
			if prompt then
				local cmd = string.format("codex --diff %q %q", prompt, filename)
				vim.cmd("botright split | term " .. cmd)
			end
		end)
	end, { desc = "Codex patch file" })

	-- Scratchpad prompt
	vim.keymap.set("n", "<leader>cs", function()
		vim.ui.input({ prompt = "Codex scratch: " }, function(prompt)
			if prompt then
				local cmd = "codex " .. vim.fn.shellescape(prompt)
				run_in_split(cmd)
			end
		end)
	end, { desc = "Codex scratchpad" })

	-- Register which-key group if available
	local ok, wk = pcall(require, "which-key")
	if ok then
		wk.add({
			{ "<leader>c", group = "Codex" },
			{ "<leader>cc", desc = "Run on selection" },
			{ "<leader>cp", desc = "Patch file" },
			{ "<leader>cs", desc = "Scratchpad" },
		})
	end
end

return M
