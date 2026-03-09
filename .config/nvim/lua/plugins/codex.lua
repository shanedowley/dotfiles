-- lua/plugins/codex.lua
return {
	{
		"ishiooon/codex.nvim",
		dependencies = { "folke/snacks.nvim" },

		-- Load on first Codex-related keypress
		cmd = { "Codex", "CodexFocus", "CodexTreeAdd" },

		config = function()
			require("codex").setup({
				status_indicator = {
					enabled = false,
				},
			})
		end,

		keys = {
			----------------------------------------------------------------
			-- Group header (restores top-level +codex in which-key)
			----------------------------------------------------------------
			{ "<leader>c", desc = "+codex" },

			----------------------------------------------------------------
			-- Terminal-based codex.nvim actions
			----------------------------------------------------------------
			{ "<leader>ct", "<cmd>Codex<cr>", desc = "Terminal: Toggle/Open" },
			{ "<leader>cT", "<cmd>CodexFocus<cr>", desc = "Terminal: Focus" },

			-- Tree views (neo-tree / oil)
			{
				"<leader>cA",
				"<cmd>CodexTreeAdd<cr>",
				ft = { "neo-tree", "oil" },
				desc = "Terminal: Add file to context",
			},

			----------------------------------------------------------------
			-- Advanced CLI workflows (your codex_cli.lua)
			----------------------------------------------------------------

			-- Visual mode actions
			{
				"<leader>cE",
				function()
					require("codex_cli").explain_selection()
				end,
				mode = "x",
				desc = "Explain selection (C learning)",
			},
			{
				"<leader>cr",
				function()
					require("codex_cli").replace_selection()
				end,
				mode = "v",
				desc = "Replace selection",
			},
			{
				"<leader>co",
				function()
					require("codex_cli").open_output_scratch()
				end,
				mode = "v",
				desc = "Open output in scratch buffer",
			},
			{
				"<leader>ca",
				function()
					require("codex_cli").apply_inline()
				end,
				mode = "v",
				desc = "Apply inline (smart diff)",
			},
			{
				"<leader>cd",
				function()
					require("codex_cli").preview_diff()
				end,
				mode = "v",
				desc = "Preview diff",
			},
			{
				"<leader>cw",
				function()
					local function get_visual_selection_text()
						local buf = 0
						local vmode = vim.fn.visualmode()
						local vpos = vim.fn.getpos("v")
						local cpos = vim.fn.getpos(".")

						local srow, scol = vpos[2], vpos[3]
						local erow, ecol = cpos[2], cpos[3]

						if (srow > erow) or (srow == erow and scol > ecol) then
							srow, erow = erow, srow
							scol, ecol = ecol, scol
						end

						if vmode == "V" then
							local lines = vim.api.nvim_buf_get_lines(buf, srow - 1, erow, false)
							return table.concat(lines, "\n")
						end

						local lines = vim.api.nvim_buf_get_text(buf, srow - 1, scol - 1, erow - 1, ecol, {})
						return table.concat(lines, "\n")
					end

					local text = get_visual_selection_text()

					vim.schedule(function()
						local esc = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
						vim.api.nvim_feedkeys(esc, "nx", false)

						vim.schedule(function()
							require("codex_cli").save_output_to_file_text(text)
						end)
					end)
				end,
				mode = "x",
				desc = "Write output to file",
			},

			-- Normal mode actions
			{
				"<leader>cR",
				function()
					require("codex_cli").replace_current_function()
				end,
				desc = "Refactor current function",
			},
			{
				"<leader>cP",
				function()
					require("codex_cli").safe_preview_confirm_apply_current_function()
				end,
				desc = "Safe refactor preview (current function)",
			},
			{
				"<leader>cl",
				function()
					require("codex_cli").run_current_line()
				end,
				desc = "Run on current line",
			},
			{
				"<leader>cF",
				function()
					require("codex_cli").run_entire_file()
				end,
				desc = "Run on entire file",
			},
			{
				"<leader>cp",
				function()
					require("codex_cli").patch_buffer()
				end,
				desc = "Patch buffer (diff)",
			},
			{
				"<leader>cs",
				function()
					local mode = vim.fn.mode()
					local is_visual = (mode == "v" or mode == "V" or mode == "\22")

					if is_visual then
						-- leave Visual mode but keep '< and '> marks so selection is still available
						vim.cmd("normal! <Esc>")
					end

					-- defer so which-key/lazy key handler finishes, then prompt can render
					vim.schedule(function()
						require("codex_cli").scratchpad_prompt()
					end)
				end,
				mode = { "n", "x" },
				desc = "Scratchpad prompt",
			},
		},
	},
}