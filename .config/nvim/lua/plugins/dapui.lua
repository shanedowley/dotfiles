-- ~/.config/nvim/lua/plugins/dapui.lua
return {
	{
		"rcarriga/nvim-dap-ui",
		dependencies = {
			"mfussenegger/nvim-dap",
			"nvim-neotest/nvim-nio",
		},

		lazy = true,

		-- Create commands even while lazy (init runs at startup)
		init = function()
			local function ensure_ui()
				-- load the plugin
				pcall(function()
					require("lazy").load({ plugins = { "nvim-dap-ui" } })
				end)

				local ok, dapui = pcall(require, "dapui")
				if not ok then
					return nil
				end
				return dapui
			end

			vim.api.nvim_create_user_command("DapUiToggle", function()
				local ui = ensure_ui()
				if ui then
					ui.toggle()
				end
			end, {})

			vim.api.nvim_create_user_command("DapUiOpen", function()
				local ui = ensure_ui()
				if ui then
					ui.open()
				end
			end, {})

			vim.api.nvim_create_user_command("DapUiClose", function()
				local ui = ensure_ui()
				if ui then
					ui.close()
				end
			end, {})

			vim.api.nvim_create_user_command("DapUiReset", function()
				local ui = ensure_ui()
				if ui then
					ui.close()
					ui.open()
				end
			end, {})
		end,

		keys = {
			{
				"<leader>du",
				function()
					vim.cmd("DapUiToggle")
				end,
				desc = "DAP: Toggle UI",
			},
		},

		-- config runs only when the plugin is actually loaded
		config = function()
			local ok, dapui = pcall(require, "dapui")
			if not ok then
				vim.notify("dapui failed to load", vim.log.levels.ERROR, { title = "nvim-dap-ui" })
				return
			end

			dapui.setup({
				floating = { border = "rounded" },
				controls = {
					enabled = true,
					element = "repl",
					icons = {
						pause = "⏸️ ",
						play = "▶️ ",
						step_into = "↳ ",
						step_over = "⤼ ",
						step_out = "⤴ ",
						step_back = "⏮️ ",
						run_last = "🔁 ",
						terminate = "⏹️ ",
					},
				},
			})
		end,
	},
}
