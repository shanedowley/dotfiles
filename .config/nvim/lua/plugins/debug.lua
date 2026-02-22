-- ~/.config/nvim/lua/plugins/debug.lua

return {
	{
		"mfussenegger/nvim-dap",
		event = "VeryLazy",
		keys = {
			{ "<leader>ad", "<cmd>DebugAsm<CR>", desc = "DAP: Build & Debug ARM64 Assembly" },
			{
				"<leader>ar",
				function()
					require("dap").run_last()
				end,
				desc = "DAP: Run last",
			},
		},

		dependencies = {
			"theHamsta/nvim-dap-virtual-text",

			-- JS/TS debug bridge + debugger runtime
			{
				"mxsdev/nvim-dap-vscode-js",
				dependencies = {
					{
						"microsoft/vscode-js-debug",
						version = "1.x",
						build = "npm ci && npm run compile",
					},
				},
			},
		},

		config = function()
			local dap = require("dap")
			dap.set_log_level("INFO")
			dap.configurations = dap.configurations or {}

			-- ------------------------------------------------
			-- Persist breakpoints across Neovim restarts
			-- ------------------------------------------------
			local breakpoint_file = vim.fn.stdpath("state") .. "/dap_breakpoints.json"
			local ok_bp, bp = pcall(require, "dap.breakpoints")

			if ok_bp then
				-- Load once when dap loads
				pcall(function()
					bp.load(breakpoint_file)
				end)

				local function save_breakpoints()
					pcall(function()
						bp.save(breakpoint_file)
					end)
				end

				-- Save when a session ends
				dap.listeners.after.event_terminated["dap_breakpoints_save"] = save_breakpoints
				dap.listeners.after.event_exited["dap_breakpoints_save"] = save_breakpoints

				-- Also save on editor exit (covers “no session” cases)
				vim.api.nvim_create_autocmd("VimLeavePre", {
					callback = save_breakpoints,
				})
			end

			-- ---- Breakpoint UX: signs + highlights ----
			vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DiagnosticError" })
			vim.fn.sign_define("DapBreakpointCondition", { text = "◆", texthl = "DiagnosticWarn" })
			vim.fn.sign_define("DapBreakpointRejected", { text = "", texthl = "DiagnosticHint" })
			vim.fn.sign_define("DapLogPoint", { text = "▶", texthl = "DiagnosticInfo" })
			vim.fn.sign_define("DapStopped", { text = "→", texthl = "DiagnosticOk", linehl = "CursorLine" })

			-- ---- dap-ui lifecycle (decoupled + deterministic) ----
			dap.listeners.after.event_initialized["dapui_autoopen"] = function()
				pcall(function()
					require("lazy").load({ plugins = { "nvim-dap-ui" } })
				end)
				pcall(function()
					require("dapui").open()
				end)
			end

			local function dapui_close()
				pcall(function()
					require("dapui").close()
				end)
			end

			dap.listeners.before.event_terminated["dapui_autoclose"] = dapui_close
			dap.listeners.before.event_exited["dapui_autoclose"] = dapui_close

			local function ensure_config(ft, cfg)
				dap.configurations[ft] = dap.configurations[ft] or {}
				for _, existing in ipairs(dap.configurations[ft]) do
					if existing.name == cfg.name then
						return
					end
				end
				table.insert(dap.configurations[ft], cfg)
			end

			-- ---- virtual text (safe) ----
			pcall(function()
				require("nvim-dap-virtual-text").setup({ highlight_new_as_changed = true })
			end)

			-- ----------------------------
			-- JavaScript / TypeScript via vscode-js-debug
			-- ----------------------------
			local ok_js_block, js_err = pcall(function()
				local ok_js, dap_vscode = pcall(require, "dap-vscode-js")
				if not ok_js then
					return
				end

				local plugins = require("lazy.core.config").plugins
				local js_debug = plugins["vscode-js-debug"]
				local debugger_path = js_debug and js_debug.dir or nil

				if not debugger_path or vim.fn.isdirectory(debugger_path) == 0 then
					error("vscode-js-debug plugin directory not found")
				end

				dap_vscode.setup({
					debugger_path = debugger_path,
					adapters = { "pwa-node", "pwa-chrome", "node-terminal" },
				})

				local js_languages = {
					"javascript",
					"typescript",
					"javascriptreact",
					"typescriptreact",
					"vue",
					"svelte",
				}

				for _, ft in ipairs(js_languages) do
					ensure_config(ft, {
						name = "Node: Launch current file",
						type = "pwa-node",
						request = "launch",
						program = "${file}",
						cwd = "${workspaceFolder}",
						runtimeExecutable = "node",
						console = "integratedTerminal",
						internalConsoleOptions = "neverOpen",
					})

					ensure_config(ft, {
						name = "Node: Attach",
						type = "pwa-node",
						request = "attach",
						processId = function()
							local ok_utils, utils = pcall(require, "dap.utils")
							if ok_utils then
								return utils.pick_process()
							end
							return nil
						end,
						cwd = "${workspaceFolder}",
					})
				end

				for _, ft in ipairs({
					"javascript",
					"typescript",
					"javascriptreact",
					"typescriptreact",
				}) do
					ensure_config(ft, {
						name = "Chrome: Attach to localhost",
						type = "pwa-chrome",
						request = "attach",
						url = "http://localhost:5173",
						webRoot = "${workspaceFolder}",
					})
				end
			end)

			if not ok_js_block then
				vim.notify(
					"dap-vscode-js setup failed: " .. tostring(js_err),
					vim.log.levels.WARN,
					{ title = "nvim-dap" }
				)
			end

			-- -----------------------------------
			-- C / C++ / ARM64 Assembly (lldb-dap)
			-- -----------------------------------
			local lldb = vim.fn.exepath("lldb-dap")
			if lldb == "" then
				lldb = "/Library/Developer/CommandLineTools/usr/bin/lldb-dap"
			end

			if lldb ~= "" then
				dap.adapters.cpp = {
					type = "executable",
					command = lldb,
					name = "cpp",
				}
				dap.adapters.lldb = dap.adapters.cpp
				dap.adapters.codelldb = dap.adapters.cpp

				local function cpp_launch()
					local cwd = vim.fn.getcwd()
					local gtest_link = cwd .. "/.neotest_gtest_exec"
					if vim.loop.fs_stat(gtest_link) then
						return gtest_link
					end

					local hello = cwd .. "/hello"
					if vim.fn.filereadable(hello) == 1 then
						return hello
					end

					local maybe = cwd .. "/" .. vim.fn.expand("%:t:r")
					if vim.fn.filereadable(maybe) == 1 then
						return maybe
					end

					return vim.fn.input("Path to executable: ", cwd .. "/", "file")
				end

				local cpp_config = {
					name = "Launch current binary",
					type = "cpp",
					request = "launch",
					program = cpp_launch,
					cwd = "${workspaceFolder}",
					stopOnEntry = false,
					args = function()
						local input = vim.fn.input("Args: ")
						return vim.split(input, " ", { trimempty = true })
					end,
				}

				-- -----------------------------------
				-- Rust (reuses CodeLLDB "cpp" adapter)
				-- -----------------------------------
				ensure_config("rust", {
					name = "Debug Rust crate (target/debug)",
					type = "cpp", -- or "codelldb" if you prefer; both map to lldb-dap
					request = "launch",
					program = function()
						local cwd = vim.fn.getcwd()
						local crate = nil
						local cargo_toml = cwd .. "/Cargo.toml"

						if vim.fn.filereadable(cargo_toml) == 1 then
							for _, line in ipairs(vim.fn.readfile(cargo_toml)) do
								local name = line:match([[^name%s*=%s*"(.*)"]])
								if name then
									crate = name
									break
								end
							end
						end

						if not crate or crate == "" then
							crate = vim.fn.fnamemodify(cwd, ":t")
						end

						local default_exe = cwd .. "/target/debug/" .. crate

						-- If the inferred binary exists, just use it
						if vim.fn.filereadable(default_exe) == 1 then
							return default_exe
						end

						-- Otherwise, prompt
						return vim.fn.input("Path to executable: ", default_exe, "file")
					end,
					cwd = "${workspaceFolder}",
					stopOnEntry = false,
					args = {},
				})

				ensure_config("cpp", cpp_config)
				ensure_config("c", vim.deepcopy(cpp_config))

				-- ARM64 assembly (uses same LLDB adapter as C/C++).
				for _, ft in ipairs({ "asm", "gas", "arm64asm" }) do
					ensure_config(ft, {
						name = "Debug ARM64 Asm (launch)",
						type = "cpp",
						request = "launch",
						program = function()
							local default = vim.fn.expand("%:p:r") .. ".out"
							return vim.fn.input("Path to ARM64 executable: ", default, "file")
						end,
						cwd = "${workspaceFolder}",
						stopOnEntry = true,
						initCommands = {
							"settings set target.run-args ''",
							"settings set target.process.stop-on-sharedlibrary-loads false",
							"settings set target.skip-prologue true",
							"breakpoint set --name _main",
						},
					})
				end
			else
				vim.notify(
					"lldb-dap not found in PATH; C/C++ debugging disabled",
					vim.log.levels.WARN,
					{ title = "nvim-dap" }
				)
			end

			-- ---------------------------------------
			-- Build & Debug commands for any .s file
			-- ---------------------------------------
			vim.api.nvim_create_user_command("DebugAsm", function()
				local ext = vim.fn.expand("%:e")
				if ext ~= "s" and ext ~= "S" then
					vim.notify("DebugAsm: not an assembly buffer (.s/.S)", vim.log.levels.WARN, { title = "nvim-dap" })
					return
				end

				local output = vim.fn.expand("%:p:r") .. ".out"
				vim.cmd(
					string.format(
						"!clang -target arm64-apple-macos -isysroot $(xcrun --show-sdk-path) -o %q %q",
						output,
						vim.fn.expand("%:p")
					)
				)
				require("dap").run({
					name = "DebugAsm (build + launch)",
					type = "cpp",
					request = "launch",
					program = output,
					cwd = vim.fn.getcwd(),
					stopOnEntry = true,
					initCommands = {
						"settings set target.run-args ''",
						"settings set target.process.stop-on-sharedlibrary-loads false",
						"settings set target.skip-prologue true",
						"breakpoint set --name _main",
					},
				})
			end, { desc = "Assemble & Debug current ARM64 source" })
		end,
	},
}
