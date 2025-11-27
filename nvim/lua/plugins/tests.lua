-- ~/.config/nvim/lua/plugins/tests.lua
return {
	{
		"nvim-neotest/neotest",
		lazy = false, -- ensure setup + keymaps are always available
		dependencies = {
			"nvim-lua/plenary.nvim",
			"nvim-neotest/nvim-nio",
			"nvim-treesitter/nvim-treesitter",
			"alfaix/neotest-gtest",
			"rouge8/neotest-rust", -- ← NEW: Rust adapter
		},
		config = function()
			local ok_neotest, neotest = pcall(require, "neotest")
			if not ok_neotest then
				vim.notify("[tests.lua] neotest NOT available", vim.log.levels.ERROR)
				return
			end

			local ok_gtest, gtest = pcall(require, "neotest-gtest")
			if not ok_gtest then
				vim.notify("[tests.lua] neotest-gtest NOT available", vim.log.levels.ERROR)
			end

			local ok_rust, neotest_rust = pcall(require, "neotest-rust")
			if not ok_rust then
				vim.notify("[tests.lua] neotest-rust NOT available", vim.log.levels.WARN)
			end

			-- Build adapters list dynamically based on what loaded
			local adapters = {}

			if ok_gtest then
				table.insert(
					adapters,
					gtest.setup({
						-- Only consider *_test.cpp files as test files
						is_test_file = function(file)
							return file:match("_test%.cpp$") ~= nil
						end,
						-- Exclude vendored/build trees from discovery
						filter_dir = function(name, rel_path)
							rel_path = rel_path or ""
							return not (
								rel_path:match("^build/_deps") -- CMake fetched deps (googletest, etc.)
								or rel_path:match("^_deps") -- any _deps at repo root
								or rel_path:match("^%.git") -- git internals
								or false -- If you want to exclude *everything* under build/, add:							-- or rel_path:match("^build/")


							)
						end,
					})
				)
			end

			if ok_rust then
				table.insert(
					adapters,
					neotest_rust({
						-- extra args passed to `cargo test`
						args = { "--nocapture" },
					})
				)
			end

			neotest.setup({
				adapters = adapters,

				-- ⬇️ Only open output panel automatically when there are failures
				output = {
					open_on_run = function(status)
						return status == "failed"
					end,
				},

				quickfix = { open = false },
				log_level = vim.log.levels.INFO,

				-- Pretty UI
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

			-- Helper: (re)link a project-local test exe so paths stay relative
			local function relink_gtest_exec()
				local root = vim.loop.cwd()
				local candidates = {
					root .. "/build/Debug",
					root .. "/build/Release",
					root .. "/build",
				}
				local exe
				for _, dir in ipairs(candidates) do
					local found = vim.fs.find(function(name, _)
						return name:match("_test$") or name:match("_test%.exe$")
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
				vim.fn.system({ "ln", "-sfn", exe, target })
				vim.notify("[neotest] Linked .neotest_gtest_exec → " .. exe, vim.log.levels.INFO)
			end
			vim.api.nvim_create_user_command("NeotestGtestLink", relink_gtest_exec, {})

			-- Runner that shows summary (output panel now handled by open_on_run above)
			local function run_and_show(pos_or_opts)
				neotest.summary.open()
				neotest.run.run(pos_or_opts or {})
			end

			-- Keymaps
			local map = function(lhs, rhs, desc)
				vim.keymap.set("n", lhs, rhs, { desc = desc, silent = true })
			end
			map("<leader>tn", function()
				run_and_show()
			end, "Test: Run nearest")
			map("<leader>tf", function()
				run_and_show(vim.fn.expand("%"))
			end, "Test: Run file")

			-- Run all tests from the current project root (avoids _deps noise)
			map("<leader>ta", function()
				local root = vim.loop.cwd()
				neotest.summary.open()
				neotest.run.run(root)
			end, "Test: Run all (project)")

			map("<leader>tR", function()
				neotest.run.run_last()
			end, "Test: Run last")
			map("<leader>ts", function()
				neotest.summary.toggle()
			end, "Test: Toggle summary")
			map("<leader>to", function()
				neotest.output.open({ enter = true })
			end, "Test: Show output")
			map("<leader>tO", function()
				neotest.output_panel.toggle()
			end, "Test: Toggle output panel")
			map("<leader>tL", relink_gtest_exec, "Test: Relink .neotest_gtest_exec")

			-- DAP debug (nearest / file)
			map("<leader>td", function()
				local ok_dap, dap = pcall(require, "dap")
				if ok_dap then
					pcall(dap.terminate)
				end
				local ok_ui, dapui = pcall(require, "dapui")
				if ok_ui then
					pcall(dapui.close)
				end
				neotest.run.run({ strategy = "dap" })
			end, "Test: Debug nearest (DAP)")

			map("<leader>tD", function()
				neotest.run.run({ vim.fn.expand("%"), strategy = "dap" })
			end, "Test: Debug file (DAP)")

			vim.notify("[tests.lua] neotest (gtest + rust) configured", vim.log.levels.INFO)
		end,
	},
}
