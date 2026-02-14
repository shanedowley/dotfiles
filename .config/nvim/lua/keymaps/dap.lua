local function dap()
	local ok, m = pcall(require, "dap")
	return ok and m or nil
end

local function dapui()
	local ok, m = pcall(require, "dapui")
	return ok and m or nil
end

local function widgets()
	local ok, m = pcall(require, "dap.ui.widgets")
	return ok and m or nil
end

local function with_dap(fn, msg)
	return function()
		local d = dap()
		if not d then
			if msg then
				vim.notify(msg, vim.log.levels.WARN)
			end
			return
		end
		fn(d)
	end
end

-- Function keys
vim.keymap.set("n", "<F5>", function()
	local ok, dap = pcall(require, "dap")
	if not ok then
		vim.notify("nvim-dap not loaded yet", vim.log.levels.WARN)
		return
	end

	-- If already debugging, continue.
	if dap.session() then
		dap.continue()
		return
	end

	-- If not debugging, prevent neotest from racing the DAP shutdown/startup path.
	pcall(function()
		local neotest = require("neotest")
		if neotest and neotest.run and neotest.run.stop then
			neotest.run.stop()
		end
	end)

	-- If not debugging, re-run last debug config (no Args prompt)
	if dap.run_last then
		dap.run_last()
	else
		dap.continue()
	end
end, { desc = "DAP: Continue / Start (smart)" })

vim.keymap.set(
	"n",
	"<F10>",
	with_dap(function(d)
		d.step_over()
	end, "nvim-dap not loaded yet"),
	{ desc = "DAP: Step Over" }
)
vim.keymap.set(
	"n",
	"<F11>",
	with_dap(function(d)
		d.step_into()
	end, "nvim-dap not loaded yet"),
	{ desc = "DAP: Step Into" }
)
vim.keymap.set(
	"n",
	"<F12>",
	with_dap(function(d)
		d.step_out()
	end, "nvim-dap not loaded yet"),
	{ desc = "DAP: Step Out" }
)

-- Breakpoints (keep them inside the Debug menu)
vim.keymap.set(
	"n",
	"<leader>db",
	with_dap(function(d)
		d.toggle_breakpoint()
	end, "nvim-dap not loaded yet"),
	{ desc = "DAP: Toggle Breakpoint" }
)

vim.keymap.set(
	"n",
	"<leader>dB",
	with_dap(function(d)
		d.set_breakpoint(vim.fn.input("Breakpoint condition: "))
	end, "nvim-dap not loaded yet"),
	{ desc = "DAP: Conditional Breakpoint" }
)

-- Add logpoints and cleaer breakpoints
vim.keymap.set(
	"n",
	"<leader>dL",
	with_dap(function(d)
		d.set_breakpoint(nil, nil, vim.fn.input("Log point message: "))
	end, "nvim-dap not loaded yet"),
	{ desc = "DAP: Log Point" }
)

vim.keymap.set(
	"n",
	"<leader>dC",
	with_dap(function(d)
		d.clear_breakpoints()
		vim.notify("DAP: Cleared all breakpoints", vim.log.levels.INFO)
	end, "nvim-dap not loaded yet"),
	{ desc = "DAP: Clear Breakpoints" }
)

-- Widgets / inspection
vim.keymap.set("n", "<leader>dh", function()
	local w = widgets()
	if w then
		w.hover()
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
	with_dap(function(d)
		d.restart_frame()
	end, "nvim-dap not loaded yet"),
	{ desc = "DAP: Restart frame" }
)
vim.keymap.set(
	"n",
	"<leader>dx",
	with_dap(function(d)
		d.terminate()
	end, "nvim-dap not loaded yet"),
	{ desc = "DAP: Terminate" }
)

vim.keymap.set("n", "<leader>dn", function()
	local ok, dap = pcall(require, "dap")
	if not ok then
		return
	end

	-- Stop any neotest runner first (same reason as dQ).
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
end, { desc = "DAP: New session (terminate + start)" })

vim.keymap.set(
	"n",
	"<leader>dc",
	with_dap(function(d)
		d.continue()
	end, "nvim-dap not loaded yet"),
	{ desc = "DAP: Continue / Start" }
)
vim.keymap.set(
	"n",
	"<leader>do",
	with_dap(function(d)
		d.step_over()
	end, "nvim-dap not loaded yet"),
	{ desc = "DAP: Step over" }
)
vim.keymap.set(
	"n",
	"<leader>di",
	with_dap(function(d)
		d.step_into()
	end, "nvim-dap not loaded yet"),
	{ desc = "DAP: Step into" }
)
vim.keymap.set(
	"n",
	"<leader>dO",
	with_dap(function(d)
		d.step_out()
	end, "nvim-dap not loaded yet"),
	{ desc = "DAP: Step out" }
)

vim.keymap.set("n", "<leader>dl", function()
	local ok, dap = pcall(require, "dap")
	if not ok then
		return
	end

	if dap.session() then
		vim.notify("DAP session already active; terminate it first (dQ) or use <leader>dn", vim.log.levels.INFO)
		return
	end

	dap.run_last()
end, { desc = "DAP: Run last (safe)" })

vim.keymap.set(
	"n",
	"<leader>dj",
	with_dap(function(d)
		d.down()
	end, "nvim-dap not loaded yet"),
	{ desc = "DAP: Frame down" }
)
vim.keymap.set(
	"n",
	"<leader>dk",
	with_dap(function(d)
		d.up()
	end, "nvim-dap not loaded yet"),
	{ desc = "DAP: Frame up" }
)

vim.keymap.set(
	"n",
	"<leader>dR",
	with_dap(function(d)
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
		pcall(function()
			require("dap").terminate()
		end)

		pcall(function()
			require("dapui").close()
		end)
	end, 50)
end, { desc = "DAP: Terminate + close UI (safe)" })

vim.keymap.set({ "n", "v" }, "<leader>de", function()
	local ui = dapui()
	if ui then
		ui.eval()
	end
end, { desc = "DAP: Eval" })

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
	with_dap(function(d)
		d.run_last()
	end, "nvim-dap not loaded yet"),
	{ desc = "DAP: Rerun last debug session" }
)
