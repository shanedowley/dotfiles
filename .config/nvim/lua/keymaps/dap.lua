local function load_dap()
	pcall(function()
		local ok, lazy = pcall(require, "lazy")
		if ok then
			lazy.load({ plugins = { "nvim-dap" } })
		end
	end)
end

local function dap_or_nil()
	load_dap()
	local ok, d = pcall(require, "dap")
	return ok and d or nil
end

local function with_dap_loaded(fn, msg)
	return function()
		local d = dap_or_nil()
		if not d then
			if msg then
				vim.notify(msg, vim.log.levels.WARN)
			end
			return
		end
		fn(d)
	end
end

local function dapui()
	pcall(function()
		local ok, lazy = pcall(require, "lazy")
		if ok then
			lazy.load({ plugins = { "nvim-dap-ui" } })
		end
	end)
	local ok, m = pcall(require, "dapui")
	return ok and m or nil
end

local function widgets()
	local dap = dap_or_nil()
	if not dap then
		return nil
	end
	local ok, m = pcall(require, "dap.ui.widgets")
	return ok and m or nil
end

local function cword_or_nil()
	local w = vim.fn.expand("<cword>")
	if not w or w == "" then
		vim.notify("No symbol under cursor", vim.log.levels.WARN)
		return nil
	end
	return w
end

local function dapui_eval_expr(expr)
	local ui = dapui()
	if not ui then
		vim.notify("nvim-dap-ui not loaded yet", vim.log.levels.WARN)
		return
	end

	local ok = pcall(function()
		ui.eval(expr)
	end)

	if not ok then
		vim.notify("DAP eval failed for expression: " .. expr, vim.log.levels.WARN)
	end
end

local function dap_repl_exec(cmd)
	local dap = dap_or_nil()
	if not dap then
		vim.notify("nvim-dap not loaded yet", vim.log.levels.WARN)
		return
	end

	pcall(function()
		dap.repl.open()
	end)

	local ok = pcall(function()
		dap.repl.execute(cmd)
	end)

	if not ok then
		vim.notify("DAP REPL command failed: " .. cmd, vim.log.levels.WARN)
	end
end

-- Function keys
vim.keymap.set("n", "<F5>", function()
	local dap = dap_or_nil()
	if not dap then
		vim.notify("nvim-dap not loaded yet", vim.log.levels.WARN)
		return
	end

	-- If already debugging, continue.
	if dap.session() then
		dap.continue()
		return
	end

	-- Otherwise do the full build + debug flow for current file.
	local ok_run, run = pcall(require, "run")
	if not ok_run or not run or not run.build_and_debug_current_c_cpp then
		vim.notify("run.build_and_debug_current_c_cpp() not available", vim.log.levels.ERROR)
		return
	end

	run.build_and_debug_current_c_cpp()
end, { desc = "DAP: Build & debug current file / Continue" })

vim.keymap.set(
	"n",
	"<F10>",
	with_dap_loaded(function(d)
		d.step_over()
	end, "nvim-dap not loaded yet"),
	{ desc = "DAP: Step Over" }
)
vim.keymap.set(
	"n",
	"<F11>",
	with_dap_loaded(function(d)
		d.step_into()
	end, "nvim-dap not loaded yet"),
	{ desc = "DAP: Step Into" }
)
vim.keymap.set(
	"n",
	"<S-F11>",
	with_dap_loaded(function(d)
		d.step_out()
	end, "nvim-dap not loaded yet"),
	{ desc = "DAP: Step Out" }
)

-- Breakpoints (runtime only, pure nvim-dap)
vim.keymap.set(
	"n",
	"<leader>db",
	with_dap_loaded(function(d)
		d.toggle_breakpoint()
	end, "nvim-dap not loaded yet"),
	{ desc = "DAP: Toggle Breakpoint" }
)
vim.keymap.set(
	"n",
	"<leader>dB",
	with_dap_loaded(function(d)
		local cond = vim.fn.input("Breakpoint condition: ")
		if cond == nil or cond == "" then
			return
		end
		d.set_breakpoint(cond)
	end, "nvim-dap not loaded yet"),
	{ desc = "DAP: Conditional Breakpoint" }
)
vim.keymap.set(
	"n",
	"<leader>dn",
	with_dap_loaded(function(dap)
		-- Stop any neotest runner first (prevents gtest JSON read race)
		pcall(function()
			local neotest = require("neotest")
			if neotest and neotest.run and neotest.run.stop then
				neotest.run.stop()
			end
		end)
		-- Terminate any active DAP session, then start fresh.
		if dap.session() then
			pcall(dap.terminate)
			vim.defer_fn(function()
				dap.continue()
			end, 80)
		else
			dap.continue()
		end
	end, "nvim-dap not loaded yet"),
	{ desc = "DAP: New session (terminate + start)" }
)
vim.keymap.set(
	"n",
	"<leader>dL",
	with_dap_loaded(function(d)
		local msg = vim.fn.input("Log point message: ")
		if msg == nil or msg == "" then
			return
		end
		d.set_breakpoint(nil, nil, msg)
	end, "nvim-dap not loaded yet"),
	{ desc = "DAP: Log Point" }
)

vim.keymap.set(
	"n",
	"<leader>dC",
	with_dap_loaded(function(d)
		d.clear_breakpoints()
		vim.notify("DAP: Cleared all runtime breakpoints", vim.log.levels.INFO)
	end, "nvim-dap not loaded yet"),
	{ desc = "DAP: Clear ALL breakpoints (runtime)" }
)

-- Widgets / inspection
vim.keymap.set("n", "<leader>dh", function()
	local w = widgets()
	if not w then
		return
	end

	-- Capture current window before opening hover
	local cur_win = vim.api.nvim_get_current_win()

	-- Open hover
	w.hover()

	-- Find the new floating window
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		if win ~= cur_win then
			local config = vim.api.nvim_win_get_config(win)
			if config.relative ~= "" then
				-- This is a floating window → bind 'q' to close it
				local buf = vim.api.nvim_win_get_buf(win)
				vim.keymap.set("n", "q", function()
					if vim.api.nvim_win_is_valid(win) then
						vim.api.nvim_win_close(win, true)
					end
				end, { buffer = buf, silent = true })

				-- Optional: also map <Esc>
				vim.keymap.set("n", "<Esc>", function()
					if vim.api.nvim_win_is_valid(win) then
						vim.api.nvim_win_close(win, true)
					end
				end, { buffer = buf, silent = true })

				break
			end
		end
	end
end, { desc = "DAP: Hover variables" })

vim.keymap.set("n", "<leader>dp", function()
	local w = widgets()
	if w then
		w.preview()
	end
end, { desc = "DAP: Preview variable" })

vim.keymap.set("n", "<leader>df", function()
	local w = widgets()
	if w then
		w.centered_float(w.frames)
	end
end, { desc = "DAP: Show frames" })

vim.keymap.set("n", "<leader>ds", function()
	local w = widgets()
	if w then
		w.centered_float(w.scopes)
	end
end, { desc = "DAP: Show scopes" })

-- Session control
vim.keymap.set(
	"n",
	"<leader>dr",
	with_dap_loaded(function(d)
		d.restart_frame()
	end, "nvim-dap not loaded yet"),
	{ desc = "DAP: Restart frame" }
)
vim.keymap.set(
	"n",
	"<leader>dx",
	with_dap_loaded(function(d)
		d.terminate()
	end, "nvim-dap not loaded yet"),
	{ desc = "DAP: Terminate" }
)
vim.keymap.set(
	"n",
	"<leader>dc",
	with_dap_loaded(function(d)
		d.continue()
	end, "nvim-dap not loaded yet"),
	{ desc = "DAP: Continue / Start" }
)
vim.keymap.set(
	"n",
	"<leader>do",
	with_dap_loaded(function(d)
		d.step_over()
	end, "nvim-dap not loaded yet"),
	{ desc = "DAP: Step over" }
)
vim.keymap.set(
	"n",
	"<leader>di",
	with_dap_loaded(function(d)
		d.step_into()
	end, "nvim-dap not loaded yet"),
	{ desc = "DAP: Step into" }
)
vim.keymap.set(
	"n",
	"<leader>dO",
	with_dap_loaded(function(d)
		d.step_out()
	end, "nvim-dap not loaded yet"),
	{ desc = "DAP: Step out" }
)
vim.keymap.set(
	"n",
	"<leader>dj",
	with_dap_loaded(function(d)
		d.down()
	end, "nvim-dap not loaded yet"),
	{ desc = "DAP: Frame down" }
)
vim.keymap.set(
	"n",
	"<leader>dk",
	with_dap_loaded(function(d)
		d.up()
	end, "nvim-dap not loaded yet"),
	{ desc = "DAP: Frame up" }
)

vim.keymap.set(
	"n",
	"<leader>dR",
	with_dap_loaded(function(d)
		d.repl.open()
	end, "nvim-dap not loaded yet"),
	{ desc = "DAP: Open REPL" }
)

vim.keymap.set("n", "<leader>dQ", function()
	-- 1) Stop neotest run (prevents gtest JSON read race)
	pcall(function()
		local neotest = require("neotest")
		if neotest and neotest.run and neotest.run.stop then
			neotest.run.stop()
		end
	end)
	-- 2) Then terminate DAP (defer slightly to let neotest unwind)
	vim.defer_fn(function()
		local dap = dap_or_nil()
		if dap then
			pcall(dap.terminate)
		end
		pcall(function()
			local ui = dapui()
			if ui then
				ui.close()
			end
		end)
	end, 50)
end, { desc = "DAP: Terminate + close UI (safe)" })

vim.keymap.set({ "n", "v" }, "<leader>de", function()
	local ui = dapui()
	if ui then
		ui.eval()
	end
end, { desc = "DAP: Eval" })

-- Memory / pointer inspection
vim.keymap.set("n", "<leader>da", function()
	local sym = cword_or_nil()
	if not sym then
		return
	end
	dapui_eval_expr("&" .. sym)
end, { desc = "DAP: Eval address of symbol" })

vim.keymap.set("n", "<leader>dv", function()
	local sym = cword_or_nil()
	if not sym then
		return
	end
	dapui_eval_expr("*" .. sym)
end, { desc = "DAP: Dereference pointer under cursor" })

vim.keymap.set("n", "<leader>dm", function()
	local expr = vim.fn.input("Memory expr: ", "&")
	if expr == nil or expr == "" then
		return
	end
	dapui_eval_expr(expr)
end, { desc = "DAP: Eval custom memory expression" })

-- First-cut LLDB watchpoint
vim.keymap.set("n", "<leader>dw", function()
	local sym = cword_or_nil()
	if not sym then
		return
	end
	dap_repl_exec("watchpoint set variable " .. sym)
	vim.notify("LLDB watchpoint command set for: " .. sym, vim.log.levels.INFO)
end, { desc = "DAP: Set LLDB watchpoint on symbol" })

-- Assembly helpers
vim.keymap.set("n", "<leader>ad", function()
	if vim.fn.exists(":DebugAsm") == 2 then
		vim.cmd("DebugAsm")
	else
		vim.notify("DebugAsm command not available yet (nvim-dap plugin not loaded?)", vim.log.levels.WARN)
	end
end, { desc = "DAP: Build & Debug ARM64 Assembly" })

vim.keymap.set(
	"n",
	"<leader>ar",
	with_dap_loaded(function(d)
		d.run_last()
	end, "nvim-dap not loaded yet"),
	{ desc = "DAP: Rerun last debug session" }
)
