-- Finalized and cleaned-up DAP config for Neovim (C/JS)
-- Shane Dowley / Sept 2025

return {
	{
		"mfussenegger/nvim-dap",
		dependencies = {
			"rcarriga/nvim-dap-ui",
			"theHamsta/nvim-dap-virtual-text",
		},
		event = "VeryLazy",
		config = function()
			local dap = require("dap")
			local dapui = require("dapui")

			-- UI setup
			dapui.setup()
			require("nvim-dap-virtual-text").setup()

			-- Auto-open/close dap-ui
			dap.listeners.after.event_initialized["dapui_config"] = function()
				dapui.open()
			end
			dap.listeners.before.event_terminated["dapui_config"] = function()
				dapui.close()
			end
			dap.listeners.before.event_exited["dapui_config"] = function()
				dapui.close()
			end

			-- ✅ Stable JS/TS Debug Adapter (manual or auto-launch)
			dap.adapters["pwa-node"] = {
				type = "server",
				host = "::1",
				port = 8123, -- Keep this consistent
			}

			-- JS/TS launch config (Node)
			dap.configurations.javascript = {
				{
					type = "pwa-node",
					request = "launch",
					name = "Node: Launch current file",
					program = "${file}",
					cwd = "${workspaceFolder}",
					runtimeExecutable = "node",
					console = "integratedTerminal",
				},
			}

			----------------------------------------------------------------------
			-- ✅ C++ (lldb-dap)
			----------------------------------------------------------------------
			dap.adapters.cpp = {
				type = "executable",
				command = "/Library/Developer/CommandLineTools/usr/bin/lldb-dap",
				name = "lldb",
			}

			dap.configurations.cpp = {
				{
					name = "Launch current binary",
					type = "cpp",
					request = "launch",
					program = function()
						return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/hello", "file")
					end,
					cwd = "${workspaceFolder}",
					stopOnEntry = false,
					args = {},
				},
			}

			-- ⛓️ Keymaps for debugging
			vim.keymap.set("n", "<F5>", function()
				dap.continue()
			end, { desc = "Start/Continue Debugging" })

			vim.keymap.set("n", "<F10>", function()
				dap.step_over()
			end, { desc = "Step Over" })

			vim.keymap.set("n", "<F11>", function()
				dap.step_into()
			end, { desc = "Step Into" })

			vim.keymap.set("n", "<F12>", function()
				dap.step_out()
			end, { desc = "Step Out" })

			----------------------------------------------------------------------
			-- ✅ Keymaps (complete debug workflow)
			----------------------------------------------------------------------
			local map = vim.keymap.set
			local opts = { silent = true, noremap = true }

			map("n", "<leader>db", dap.toggle_breakpoint, { desc = "Toggle Breakpoint" })
			map("n", "<leader>dB", function()
				dap.set_breakpoint(vim.fn.input("Breakpoint condition: "))
			end, { desc = "Set Conditional Breakpoint" })

			map("n", "<leader>dc", dap.continue, { desc = "(F5) Continue / Start Debugging" })
			map("n", "<leader>dr", dap.run_last, { desc = "Run Last Debug" })
			map("n", "<leader>dx", dap.terminate, { desc = "Terminate Debug" })

			map("n", "<leader>do", dap.step_over, { desc = "(F10) Step Over" })
			map("n", "<leader>di", dap.step_into, { desc = "(F11) Step Into" })
			map("n", "<leader>dO", dap.step_out, { desc = "(F12) Step Out" })

			map("n", "<leader>dh", function()
				require("dap.ui.widgets").hover()
			end, { desc = "Hover Variables" })
			map("n", "<leader>dp", function()
				require("dap.ui.widgets").preview()
			end, { desc = "Preview Variable" })

			map("n", "<leader>df", function()
				local widgets = require("dap.ui.widgets")
				widgets.centered_float(widgets.frames)
			end, { desc = "Show Frames" })
			map("n", "<leader>ds", function()
				local widgets = require("dap.ui.widgets")
				widgets.centered_float(widgets.scopes)
			end, { desc = "Show Scopes" })

			map("n", "<leader>de", dapui.eval, { desc = "Eval Expression (UI)" })
			map("v", "<leader>de", dapui.eval, { desc = "Eval Selection (UI)" })

			-- 🪟 Optional UI toggles (if using nvim-dap-ui)
			vim.keymap.set("n", "<leader>du", function()
				require("dapui").toggle()
			end, { desc = "Toggle DAP UI" })
		end,
	},

	{
		"rcarriga/nvim-dap-ui",
		dependencies = { "nvim-neotest/nvim-nio" },
		config = function()
			local dapui = require("dapui")
			dapui.setup()

			local dap = require("dap")
			dap.listeners.after.event_initialized["dapui_config"] = function()
				dapui.open()
			end
			dap.listeners.before.event_terminated["dapui_config"] = function()
				dapui.close()
			end
			dap.listeners.before.event_exited["dapui_config"] = function()
				dapui.close()
			end
		end,
	},

	-- 🔌 Auto-launch JS Debug Adapter only once
	{
		"mxsdev/nvim-dap-vscode-js",
		config = function()
			local dap_vscode = require("dap-vscode-js")
			local dap = require("dap")

			dap_vscode.setup({})

			local server_running = false
			local Job = require("plenary.job")

			-- Check port 8123 before starting
			Job:new({
				command = "lsof",
				args = { "-i", ":8123" },
				on_exit = function(j)
					if j:result() == nil or #j:result() == 0 then
						server_running = false
						Job:new({
							command = vim.fn.stdpath("data") .. "/mason/bin/js-debug-adapter",
							args = { "8123" },
							detached = true,
						}):start()
					end
				end,
			}):start()
		end,
	},
}
