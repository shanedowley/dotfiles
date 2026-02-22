-- ~/.config/nvim/lua/plugins/tests.lua
return {
	{
		"nvim-neotest/neotest",
		version = "v4.*",
		lazy = true,
		keys = {
			{
				"<leader>tn",
				function()
					local nt = require("neotest")
					nt.summary.open()
					nt.run.run()
				end,
				desc = "Test: Run nearest",
			},
			{
				"<leader>tf",
				function()
					local nt = require("neotest")
					nt.summary.open()
					nt.run.run(vim.fn.expand("%:p"))
				end,
				desc = "Test: Run file",
			},
			{
				"<leader>ta",
				function()
					if _G.NeotestRunProject then
						_G.NeotestRunProject()
						return
					end
					local nt = require("neotest")
					nt.summary.open()
					nt.run.run(vim.loop.cwd())
				end,
				desc = "Test: Run all (project)",
			},

			{
				"<leader>tR",
				function()
					local nt = require("neotest")
					nt.summary.open()
					nt.run.run_last()
				end,
				desc = "Test: Run last",
			},
			{
				"<leader>ts",
				function()
					require("neotest").summary.toggle()
				end,
				desc = "Test: Toggle summary",
			},
			{
				"<leader>to",
				function()
					require("neotest").output.open({ enter = true })
				end,
				desc = "Test: Show output",
			},
			{
				"<leader>tO",
				function()
					require("neotest").output_panel.toggle()
				end,
				desc = "Test: Toggle output panel",
			},
			{
				"<leader>td",
				function()
					if _G.NeotestDebugNearest then
						_G.NeotestDebugNearest()
					end
				end,
				desc = "Test: Debug nearest gtest (DAP) + refresh ticks",
			},
			{
				"<leader>tG",
				function()
					if _G.NeotestDebugSuite then
						_G.NeotestDebugSuite()
					end
				end,
				desc = "Test: Debug suite/all gtest (DAP) + refresh ticks",
			},
			{
				"<leader>tD",
				function()
					if _G.NeotestDebugCustom then
						_G.NeotestDebugCustom()
					end
				end,
				desc = "Test: Debug gtest (custom args)",
			},
		},

		dependencies = {
			"nvim-lua/plenary.nvim",
			"nvim-treesitter/nvim-treesitter",
			"nvim-neotest/nvim-nio",

			-- Pick ONE gtest adapter (keep the pinned one)
			{
				"alfaix/neotest-gtest",
				commit = "b66f1d3",
			},

			-- Rust adapter ONCE
			{ "rouge8/neotest-rust", name = "neotest-rust" },
		},

		config = function()
			local function load_lazy(name)
				local ok, lazy = pcall(require, "lazy")
				if ok then
					pcall(function()
						lazy.load({ plugins = { name } })
					end)
				end
			end

			local ok_neotest, neotest = pcall(require, "neotest")
			if not ok_neotest then
				vim.notify("[tests.lua] neotest NOT available", vim.log.levels.ERROR)
				return
			end

			local lib = require("neotest.lib")

			local ok_rust, neotest_rust = pcall(require, "neotest-rust")
			if not ok_rust then
				vim.notify("[tests.lua] neotest-rust NOT available", vim.log.levels.WARN)
			end

			-- Build adapters list dynamically based on what loaded
			local adapters = {}

			local ok_gtest, gtest = pcall(require, "neotest-gtest")
			if ok_gtest then
				local gtest_adapter = gtest.setup({
					is_test_file = function(file_path)
						return file_path:match("_test%.cpp$") ~= nil
					end,

					mappings = {
						configure = "C",
					},

					root = lib.files.match_root_pattern(
						"compile_commands.json",
						"compile_flags.txt",
						"CMakeLists.txt",
						".clangd",
						".git"
					),

					filter_dir = function(name)
						return not (name == ".git" or name == "_deps" or name == "CMakeFiles")
					end,

					executable = function()
						local root = lib.files.match_root_pattern(
							"compile_commands.json",
							"compile_flags.txt",
							"CMakeLists.txt",
							".clangd",
							".git"
						)(vim.loop.cwd()) or vim.loop.cwd()

						return root .. "/.neotest_gtest_exec"
					end,
				})

				table.insert(adapters, gtest_adapter)
			else
				vim.notify("[tests.lua] neotest-gtest NOT available", vim.log.levels.ERROR)
			end

			if ok_rust then
				table.insert(adapters, neotest_rust({ args = { "--nocapture" } }))
			end

			neotest.setup({
				adapters = adapters,

				discovery = {
					enabled = true,
					filter_dir = function(name, rel_path)
						rel_path = rel_path or ""
						return not (rel_path == "lazy" or rel_path:match("^lazy/") or rel_path:match("/lazy/"))
					end,
				},

				output = {
					open_on_run = function(status)
						return status == "failed"
					end,
				},

				quickfix = { open = false },
				log_level = vim.log.levels.INFO,

				icons = {
					running_animated = { "⠋", "⠙", "⠸", "⠴", "⠦", "⠇" },
					passed = "✔",
					failed = "✘",
					running = "▶",
					skipped = "⚠",
					unknown = "?",
				},

				highlights = {
					passed = "DiagnosticOk",
					failed = "DiagnosticError",
					running = "DiagnosticWarn",
					skipped = "DiagnosticInfo",
				},
			})

			-- Helper: Jump to C++ window explicitly
			local function focus_cpp_window()
				local cur_win = vim.api.nvim_get_current_win()
				local cur_buf = vim.api.nvim_win_get_buf(cur_win)
				local cur_ft = vim.bo[cur_buf].filetype
				local cur_name = vim.api.nvim_buf_get_name(cur_buf)

				if (cur_ft == "cpp" or cur_ft == "c") and cur_name ~= "" then
					return true
				end

				for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
					local buf = vim.api.nvim_win_get_buf(win)
					local ft = vim.bo[buf].filetype
					local name = vim.api.nvim_buf_get_name(buf)
					if (ft == "cpp" or ft == "c") and name:match("_test%.cpp$") then
						vim.api.nvim_set_current_win(win)
						return true
					end
				end

				for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
					local buf = vim.api.nvim_win_get_buf(win)
					local ft = vim.bo[buf].filetype
					local name = vim.api.nvim_buf_get_name(buf)
					if (ft == "cpp" or ft == "c") and name ~= "" then
						vim.api.nvim_set_current_win(win)
						return true
					end
				end

				return false
			end

			-- Helper: (re)link a project-local test exe so paths stay relative
			local function relink_gtest_exec()
				local buf = vim.api.nvim_buf_get_name(0)
				local root = lib.files.match_root_pattern(
					"compile_commands.json",
					"compile_flags.txt",
					"CMakeLists.txt",
					".clangd",
					".git"
				)(buf ~= "" and buf or vim.loop.cwd()) or vim.loop.cwd()

				local candidates = {
					root .. "/build",
					root .. "/build/Debug",
					root .. "/build/Release",
				}

				local exe
				for _, dir in ipairs(candidates) do
					local found = vim.fs.find(function(name, _)
						return name:match(".*_test$") or name:match(".*_test%.exe$")
					end, { path = dir, type = "file", limit = 1 })
					if #found > 0 then
						exe = found[1]
						break
					end
				end

				if not exe then
					vim.notify("[neotest] No *_test binary found under build dirs", vim.log.levels.WARN)
					return
				end

				local target = root .. "/.neotest_gtest_exec"
				if vim.loop.fs_stat(target) == nil then
					vim.fn.system({ "ln", "-sfn", exe, target })
				else
					local current = vim.fn.resolve(target)
					if current ~= exe then
						vim.fn.system({ "ln", "-sfn", exe, target })
					end
				end
			end
			vim.api.nvim_create_user_command("NeotestGtestLink", relink_gtest_exec, {})

			-- ------------------------------------------
			-- DAP debug helpers (stable) + tick refresh
			-- ------------------------------------------

			local function current_gtest_suite()
				local bufnr = vim.api.nvim_get_current_buf()
				local row = vim.api.nvim_win_get_cursor(0)[1]

				for i = row, math.max(1, row - 300), -1 do
					local line = (vim.api.nvim_buf_get_lines(bufnr, i - 1, i, false)[1] or "")
					local m = vim.fn.matchlist(
						line,
						[[\v^\s*(TEST|TEST_F|TEST_P|TYPED_TEST|TYPED_TEST_P|FRIEND_TEST)\s*\(\s*([A-Za-z0-9_:]+)\s*,\s*([A-Za-z0-9_:]+)\s*\)]]
					)
					if m and m[3] and m[3] ~= "" then
						local suite = m[3]:gsub("[^%w_:]+$", "")
						return suite
					end
				end

				return nil
			end

			local function nearest_gtest_filter()
				local bufnr = vim.api.nvim_get_current_buf()
				local row = vim.api.nvim_win_get_cursor(0)[1]

				for i = row, math.max(1, row - 300), -1 do
					local line = (vim.api.nvim_buf_get_lines(bufnr, i - 1, i, false)[1] or "")
					local m = vim.fn.matchlist(
						line,
						[[\v^\s*(TEST|TEST_F|TEST_P|TYPED_TEST|TYPED_TEST_P|FRIEND_TEST)\s*\(\s*([A-Za-z0-9_:]+)\s*,\s*([A-Za-z0-9_:]+)\s*\)]]
					)
					if m and m[3] and m[4] and m[3] ~= "" and m[4] ~= "" then
						local suite = (m[3] or ""):gsub("[^%w_:]+$", "")
						local name = (m[4] or ""):gsub("[^%w_:]+$", "")
						return suite .. "." .. name
					end
				end

				return nil
			end

			local function project_root_for_buf(buf)
				return lib.files.match_root_pattern(
					"compile_commands.json",
					"compile_flags.txt",
					"CMakeLists.txt",
					".clangd",
					".git"
				)(buf ~= "" and buf or vim.loop.cwd()) or vim.loop.cwd()
			end

			_G.NeotestRunProject = function()
				local buf = vim.api.nvim_buf_get_name(0)
				local root = project_root_for_buf(buf)
				neotest.summary.open()
				neotest.run.run(root)
			end

			local function dap_run_and_refresh(refresh_fn, dap_run_fn)
				load_lazy("nvim-dap")
				local ok_dap, dap = pcall(require, "dap")
				if not ok_dap then
					vim.notify("[tests.lua] nvim-dap not available", vim.log.levels.ERROR)
					return
				end

				local key = ("neotest_refresh_%d_%d"):format(
					vim.fn.getpid(),
					vim.fn.reltimefloat(vim.fn.reltime()) * 1e6
				)

				local function done()
					dap.listeners.after.event_terminated[key] = nil
					dap.listeners.after.event_exited[key] = nil
					if type(refresh_fn) == "function" then
						vim.schedule(refresh_fn)
					end
				end

				dap.listeners.after.event_terminated[key] = done
				dap.listeners.after.event_exited[key] = done

				dap_run_fn()
			end

			local function debug_nearest_gtest_dap()
				if not focus_cpp_window() then
					vim.notify("[tests.lua] No C/C++ window found in this tab", vim.log.levels.ERROR)
					return
				end

				relink_gtest_exec()

				local buf = vim.api.nvim_buf_get_name(0)
				local root = project_root_for_buf(buf)
				local program = root .. "/.neotest_gtest_exec"

				if vim.loop.fs_stat(program) == nil then
					vim.notify(
						"[dap] Missing " .. program .. " (run :NeotestGtestLink or build tests)",
						vim.log.levels.ERROR
					)
					return
				end

				load_lazy("nvim-dap")
				local dap = require("dap")
				local filter = nearest_gtest_filter()
				local default_args = filter and ("--gtest_filter=" .. filter) or "--gtest_filter=*"
				local args_input = vim.fn.input("[td] Args: ", default_args)
				local args = vim.split(args_input, " ", { trimempty = true })

				pcall(function()
					load_lazy("nvim-dap-ui")
					require("dapui").open()
				end)

				dap_run_and_refresh(function()
					-- After debug ends, refresh neotest ticks (nearest)
					neotest.summary.open()
					neotest.run.run() -- nearest
				end, function()
					dap.run({
						name = "Debug nearest gtest",
						type = "cpp",
						request = "launch",
						program = program,
						cwd = root,
						stopOnEntry = false,
						args = args,
					})
				end)
			end

			local function debug_suite_gtest_dap()
				if not focus_cpp_window() then
					vim.notify("[tests.lua] No C/C++ window found in this tab", vim.log.levels.ERROR)
					return
				end

				relink_gtest_exec()

				local buf = vim.api.nvim_buf_get_name(0)
				local root = project_root_for_buf(buf)
				local program = root .. "/.neotest_gtest_exec"

				if vim.loop.fs_stat(program) == nil then
					vim.notify(
						"[dap] Missing " .. program .. " (run :NeotestGtestLink or build tests)",
						vim.log.levels.ERROR
					)
					return
				end

				load_lazy("nvim-dap")
				local dap = require("dap")

				local suite = current_gtest_suite()
				local default_args = suite and ("--gtest_filter=" .. suite .. ".*") or "--gtest_filter=*"
				local args_input = vim.fn.input("[tG] Args: ", default_args)
				local args = vim.split(args_input, " ", { trimempty = true })

				neotest.summary.open()
				pcall(function()
					load_lazy("nvim-dap-ui")
					require("dapui").open()
				end)

				dap_run_and_refresh(function()
					-- After debug ends, refresh ticks at project scope
					neotest.summary.open()
					neotest.run.run(root)
				end, function()
					dap.run({
						name = "Debug gtest suite/all",
						type = "cpp",
						request = "launch",
						program = program,
						cwd = root,
						stopOnEntry = false,
						args = args,
					})
				end)
			end

			_G.NeotestDebugNearest = debug_nearest_gtest_dap
			_G.NeotestDebugSuite = debug_suite_gtest_dap
			_G.NeotestDebugCustom = function()
				if not focus_cpp_window() then
					vim.notify("[tests.lua] No C/C++ window found in this tab", vim.log.levels.ERROR)
					return
				end

				relink_gtest_exec()

				local buf = vim.api.nvim_buf_get_name(0)
				local root = project_root_for_buf(buf)
				local program = root .. "/.neotest_gtest_exec"

				if vim.loop.fs_stat(program) == nil then
					vim.notify(
						"[dap] Missing " .. program .. " (run :NeotestGtestLink or build tests)",
						vim.log.levels.ERROR
					)
					return
				end

				load_lazy("nvim-dap")
				local ok_dap, dap = pcall(require, "dap")
				if not ok_dap then
					vim.notify("[tests.lua] nvim-dap not available", vim.log.levels.ERROR)
					return
				end

				local args_input = vim.fn.input("[tD] Args: ", "--gtest_filter=*")
				local args = vim.split(args_input, " ", { trimempty = true })

				pcall(function()
					load_lazy("nvim-dap-ui")
					require("dapui").open()
				end)

				dap.run({
					name = "Debug gtest (custom args)",
					type = "cpp",
					request = "launch",
					program = program,
					cwd = root,
					stopOnEntry = false,
					args = args,
				})
			end

			-- Make <leader>t* behave sensibly inside the neotest summary buffer
			vim.api.nvim_create_autocmd("FileType", {
				pattern = "neotest-summary",
				callback = function(ev)
					local function feed(keys)
						vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "m", false)
					end

					vim.keymap.set("n", "<leader>tn", function()
						feed("r")
					end, { buffer = ev.buf, silent = true, desc = "Test: Run node (summary)" })

					vim.keymap.set("n", "<leader>tf", function()
						feed("r")
					end, { buffer = ev.buf, silent = true, desc = "Test: Run file/node (summary)" })

					vim.keymap.set("n", "<leader>ta", function()
						feed("r")
					end, { buffer = ev.buf, silent = true, desc = "Test: Run suite/project node (summary)" })
				end,
			})
		end,
	},
}
