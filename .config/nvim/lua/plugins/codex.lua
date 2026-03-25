-- lua/plugins/codex.lua
return {
	{
		"ishiooon/codex.nvim",
		enabled = false,
	},

	{
		"folke/which-key.nvim",
		opts = function(_, opts)
			opts = opts or {}
			opts.spec = opts.spec or {}

			table.insert(opts.spec, { "<leader>c", group = "codex", mode = { "n", "x" } })

			return opts
		end,
	},

	{
		"nvim-lua/plenary.nvim",
		lazy = true,
	},

	{
		"nvim-telescope/telescope.nvim",
		lazy = true,
	},
	{
		dir = vim.fn.stdpath("config"),
		name = "codex-cli-workflow",
		lazy = false,
		keys = {
			-- Visual mode actions
			{
				"<leader>cE",
				function()
					require("codex_cli").explain_selection()
				end,
				mode = "x",
				desc = "Explain selection",
			},
			{
				"<leader>cr",
				function()
					require("codex_cli").replace_selection()
				end,
				mode = "x",
				desc = "Replace selection",
			},
			{
				"<leader>co",
				function()
					require("codex_cli").open_output_scratch()
				end,
				mode = "x",
				desc = "Open output scratch",
			},
			{
				"<leader>ca",
				function()
					require("codex_cli").apply_inline()
				end,
				mode = "x",
				desc = "Apply inline",
			},
			{
				"<leader>cd",
				function()
					require("codex_cli").preview_diff()
				end,
				mode = "x",
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
				"<leader>cc",
				function()
					require("codex_cli").toggle_context()
				end,
				desc = "Toggle Codex context injection",
			},
			{
				"<leader>cC",
				function()
					require("codex_cli").show_context()
				end,
				desc = "Show Codex project context",
			},
			{
				"<leader>cE",
				function()
					require("codex_cli").explain_current_line()
				end,
				desc = "Explain current line",
			},
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
				"<leader>cD",
				function()
					require("codex_cli").preview_diff_current_line()
				end,
				desc = "Preview diff (current line)",
			},
			{
				"<leader>cL",
				function()
					require("codex_log").open_log()
				end,
				desc = "Open Codex log",
			},
			{
				"<leader>cH",
				function()
					require("codex_cli").health_check()
				end,
				desc = "Codex health check",
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
						vim.cmd("normal! <Esc>")
					end

					vim.schedule(function()
						require("codex_cli").scratchpad_prompt()
					end)
				end,
				mode = { "n", "x" },
				desc = "Scratchpad prompt",
			},
			{
				"<leader>cS",
				function()
					require("codex_cli").show_state()
				end,
				desc = "Show Codex workflow state",
			},
			{
				"<leader>cT",
				function()
					require("codex_cli").show_latency()
				end,
				desc = "Show Codex latency report",
			},
			{
				"<leader>cV",
				function()
					require("codex_cli").show_prompt_version()
				end,
				desc = "Show Codex prompt version info",
			},
			{
				"<leader>cX",
				function()
					require("codex_cli").show_recovery()
				end,
				desc = "Show Codex recovery report",
			},
			{
				"<leader>c,",
				function()
					require("codex_cli").show_last_op()
				end,
				desc = "Show last Codex operation",
			},
			{
				"<leader>c.",
				function()
					require("codex_cli").repeat_last_op()
				end,
				desc = "Repeat last Codex prompt",
			},
		},
	},
}