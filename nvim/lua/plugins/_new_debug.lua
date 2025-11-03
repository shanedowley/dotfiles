-- Unified DAP stack (C/C++ + JavaScript/TypeScript) with UI and virtual text.
return {
	{
		"mfussenegger/nvim-dap",
		event = "VeryLazy",
		dependencies = {
			-- UI + widgets
			{
				"rcarriga/nvim-dap-ui",
				dependencies = { "nvim-neotest/nvim-nio" },
			},
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
			dap.set_log_level("TRACE")
			local dapui = require("dapui")

			-- ----------------------------
			-- UI + virtual text
			-- ----------------------------
			dapui.setup({
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
				floating = { border = "rounded" },
			})

			require("nvim-dap-virtual-text").setup({
				highlight_new_as_changed = true,
			})

			-- Auto-open / close the UI alongside DAP sessions.
			dap.listeners.after.event_initialized["dapui_config"] = function()
				dapui.open()
			end
			dap.listeners.before.event_terminated["dapui_config"] = function()
				dapui.close()
			end
			dap.listeners.before.event_exited["dapui_config"] = function()
				dapui.close()
			end

			-- ----------------------------
			-- Helper: map if unused (avoid double mappings with user keymaps)
			-- ----------------------------
			local function map(mode, lhs, rhs, desc, opts)
				opts = opts or {}
				opts.desc = desc
				opts.silent = opts.silent ~= false
				opts.noremap = opts.noremap ~= false
				if vim.fn.mapcheck(lhs, mode) ~= "" then
					return
				end
				vim.keymap.set(mode, lhs, rhs, opts)
			end

			-- Extra helper mappings (only if not already defined elsewhere)
			map("n", "<leader>dc", dap.continue, "DAP: Continue / Start")
			map("n", "<leader>do", dap.step_over, "DAP: Step over")
			map("n", "<leader>di", dap.step_into, "DAP: Step into")
			map("n", "<leader>dO", dap.step_out, "DAP: Step out")
			map("n", "<leader>dl", dap.run_last, "DAP: Run last")
			map("n", "<leader>dr", dap.repl.toggle, "DAP: Toggle REPL")
			map("n", "<leader>de", function()
				dapui.eval()
			end, "DAP: Eval expression")
			map("v", "<leader>de", function()
				dapui.eval()
			end, "DAP: Eval selection")
			map("n", "<leader>df", function()
				require("dap.ui.widgets").centered_float(require("dap.ui.widgets").frames)
			end, "DAP: Show frames")
			map("n", "<leader>ds", function()
				require("dap.ui.widgets").centered_float(require("dap.ui.widgets").scopes)
			end, "DAP: Show scopes")
			map("n", "<leader>du", function()
				dapui.toggle()
			end, "DAP: Toggle UI")

			-- ----------------------------
			-- JavaScript / TypeScript via vscode-js-debug
			-- ----------------------------
			local ok_js, dap_vscode = pcall(require, "dap-vscode-js")
			if ok_js then
				local debugger_path = nil
				local mason_path = vim.fn.stdpath("data") .. "/mason/packages/js-debug-adapter"
				if vim.fn.isdirectory(mason_path) == 1 then
					debugger_path = mason_path
				else
					local lazy_path = vim.fn.stdpath("data") .. "/lazy/vscode-js-debug"
					if vim.fn.isdirectory(lazy_path) == 1 then
						debugger_path = lazy_path
					end
				end

				dap_vscode.setup({
					debugger_path = debugger_path,
					adapters = { "pwa-node", "pwa-chrome", "node-terminal" },
				})

				local function ensure(ft, cfg)
					dap.configurations[ft] = dap.configurations[ft] or {}
					for _, existing in ipairs(dap.configurations[ft]) do
						if existing.name == cfg.name then
							return
						end
					end
					table.insert(dap.configurations[ft], cfg)
				end

				local js_languages = {
					"javascript",
					"typescript",
					"javascriptreact",
					"typescriptreact",
					"vue",
					"svelte",
				}

				for _, ft in ipairs(js_languages) do
					ensure(ft, {
						name = "Node: Launch current file",
						type = "pwa-node",
						request = "launch",
						program = "${file}",
						cwd = "${workspaceFolder}",
						runtimeExecutable = "node",
						console = "integratedTerminal",
					})
					ensure(ft, {
						name = "Node: Attach",
						type = "pwa-node",
						request = "attach",
						processId = require("dap.utils").pick_process,
						cwd = "${workspaceFolder}",
					})
				end
				for _, ft in ipairs({
					"javascript",
					"typescript",
					"javascriptreact",
					"typescriptreact",
				}) do
					ensure(ft, {
						name = "Chrome: Attach to localhost",
						type = "pwa-chrome",
						request = "attach",
						url = "http://localhost:5173",
						webRoot = "${workspaceFolder}",
					})
				end
			end

			-- ----------------------------
			-- C / C++ / ARM64 Assembly (lldb-dap)
			-- ----------------------------
			-- Prefer Mason-installed CodeLLDB, fallback to system lldb-dap.
			local lldb = vim.fn.stdpath("data") .. "/mason/bin/codelldb"
			if vim.fn.filereadable(lldb) == 0 then
				lldb = vim.fn.exepath("lldb-dap")
			end
			if lldb == "" then
				lldb = "/Library/Developer/CommandLineTools/usr/bin/lldb-dap"
			end

			if lldb ~= "" then
				dap.adapters.cpp = {
					type = "executable",
					command = lldb,
					args = { "--" },
					name = "cpp",
					attach = { pidProperty = "pid", pidSelect = "ask" },
				}
				dap.adapters.lldb = dap.adapters.cpp

				local function cpp_launch()
					return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
				end

				local cpp_config = {
					name = "Launch current binary",
					type = "cpp",
					request = "launch",
					program = cpp_launch,
					cwd = "${workspaceFolder}",
					stopOnEntry = false,
					args = {},
				}

				dap.configurations.c = dap.configurations.c or {}
				dap.configurations.cpp = dap.configurations.cpp or {}

				-- Custom debug config for Chocolate Doom binary
				table.insert(dap.configurations.c, {
					name = "Debug Chocolate Doom",
					type = "cpp",
					request = "launch",
					program = function()
						local cwd = vim.fn.getcwd()
						local root = cwd:gsub("/src/[^/]+$", "") -- strip /src/<subdir> if present
						return vim.fn.fnamemodify(root .. "/src/chocolate-doom", ":p") -- absolute path
					end,
					cwd = "${workspaceFolder}",
					stopOnEntry = false,
					args = {
						"-iwad",
						vim.fn.expand("$HOME/Library/Application Support/gzdoom/doom.wad"),
						"-nosound",
						"-nogui",
						"-nograph",
					},
					initCommands = (function()
						local cwd = vim.fn.getcwd()
						local root = cwd:gsub("/src/[^/]+$", "")
						local exe = vim.fn.fnamemodify(root .. "/src/chocolate-doom", ":p")
						local dsym = vim.fn.fnamemodify(root .. "/src/chocolate-doom.dSYM", ":p")
						return {
							"target create " .. exe,
							"target symbols add " .. dsym,
							"breakpoint set --name D_DoomLoop",
						}
					end)(),
				})

				if #dap.configurations.cpp == 0 then
					table.insert(dap.configurations.cpp, cpp_config)
				end

				if #dap.configurations.c == 0 then
					table.insert(dap.configurations.c, vim.deepcopy(cpp_config))
				end

				-- ARM64 assembly (uses same LLDB adapter as C/C++).
				dap.configurations.asm = dap.configurations.asm or {}
				table.insert(dap.configurations.asm, {
					name = "Debug ARM64 Assembly",
					type = "cpp",
					request = "launch",
					program = function()
						local default = vim.fn.expand("%:p:r")
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

				-- Auto-detect .s / .S files
				vim.api.nvim_create_autocmd("FileType", {
					pattern = { "asm", "arm64asm", "gas" },
					callback = function()
						require("dap").configurations.asm = require("dap").configurations.asm or {}
					end,
				})
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
				local output = vim.fn.expand("%:p:r") .. ".out"
				vim.cmd("!clang -target arm64-apple-macos -isysroot $(xcrun --show-sdk-path) -o " .. output .. " %")
				require("dap").run({
					name = "Debug ARM64 Assembly",
					type = "cpp",
					request = "launch",
					program = output,
					cwd = vim.fn.getcwd(),
					stopOnEntry = true,
					initCommands = {
						"settings set target.process.stop-on-sharedlibrary-loads false",
						"settings set target.skip-prologue true",
						"breakpoint set --name _main",
					},
				})
			end, { desc = "Assemble & Debug current ARM64 source" })

			vim.keymap.set("n", "<leader>ad", ":DebugAsm<CR>", { desc = "Build & Debug ARM64 Assembly" })

			vim.keymap.set("n", "<leader>ar", function()
				require("dap").run_last()
			end, { desc = "Rerun last ARM64 Debug" })
		end,
	},
}
