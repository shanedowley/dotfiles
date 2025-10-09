local map = vim.keymap.set

local function nmap(lhs, rhs, desc, opts)
	opts = opts or {}
	opts.desc = desc
	opts.silent = opts.silent ~= false
	opts.noremap = opts.noremap ~= false
	map("n", lhs, rhs, opts)
end

-- which-key hint scaffolding (kept minimal here; full menu lives in plugins/_new_whichkey.lua)
pcall(function()
	local wk = require("which-key")
	wk.register({
		e = "Explorer",
		f = { name = "Find", f = "Files", g = "Grep", b = "Buffers", h = "Help" },
		s = { name = "Session" },
		b = { name = "Buffer" },
		d = { name = "Debug" },
		t = { name = "Tabs" },
		w = "Write",
		q = "Quit",
	}, { prefix = "<leader>" })
end)

-- ---------------------------------------------------------------------------
-- General
-- ---------------------------------------------------------------------------

nmap("<leader>w", function()
	vim.cmd.write()
end, "Save file")

nmap("<leader>q", function()
	vim.cmd.quit()
end, "Quit window")

nmap("<leader>e", "<cmd>NvimTreeToggle<CR>", "Toggle file tree")

nmap("<leader>ff", "<cmd>Telescope find_files<CR>", "Find files")
nmap("<leader>fg", "<cmd>Telescope live_grep<CR>", "Live grep")
nmap("<leader>fb", "<cmd>Telescope buffers<CR>", "List buffers")
nmap("<leader>fh", "<cmd>Telescope help_tags<CR>", "Find help")

-- Buffer helpers under <leader>b
nmap("<leader>bb", "<cmd>Telescope buffers<CR>", "Buffers")
nmap("<leader>bn", "<cmd>bnext<CR>", "Next buffer")
nmap("<leader>bp", "<cmd>bprevious<CR>", "Prev buffer")
nmap("<leader>bd", "<cmd>bdelete<CR>", "Delete buffer")

-- Move lines up/down with Alt-j/k
map("n", "<A-j>", ":m .+1<CR>==", { silent = true })
map("n", "<A-k>", ":m .-2<CR>==", { silent = true })
map("i", "<A-j>", "<Esc>:m .+1<CR>==gi", { silent = true })
map("i", "<A-k>", "<Esc>:m .-2<CR>==gi", { silent = true })
map("v", "<A-j>", ":m '>+1<CR>gv=gv", { silent = true })
map("v", "<A-k>", ":m '<-2<CR>gv=gv", { silent = true })

-- Window navigation
nmap("<leader>h", "<C-w>h", "Move to left pane")
nmap("<leader>l", "<C-w>l", "Move to right pane")
nmap("<leader>j", "<C-w>j", "Move to lower pane")
nmap("<leader>k", "<C-w>k", "Move to upper pane")

-- Window resizing
nmap("<leader><Up>", ":resize -2<CR>", "Shrink pane height")
nmap("<leader><Down>", ":resize +2<CR>", "Grow pane height")
nmap("<leader><Left>", ":vertical resize -2<CR>", "Shrink pane width")
nmap("<leader><Right>", ":vertical resize +2<CR>", "Grow pane width")

-- macOS browser preview of current file
nmap("<leader>bp", ":!open -a Safari.app %<CR>", "Browser preview")

-- ---------------------------------------------------------------------------
-- Debug Adapter Protocol (DAP)
-- ---------------------------------------------------------------------------
do
	local dap_ok, dap = pcall(require, "dap")
	if dap_ok then
		nmap("<F5>", function()
			dap.continue()
		end, "DAP: Continue / Start")

		nmap("<F10>", function()
			dap.step_over()
		end, "DAP: Step over")

		nmap("<F11>", function()
			dap.step_into()
		end, "DAP: Step into")

		nmap("<F12>", function()
			dap.step_out()
		end, "DAP: Step out")

		nmap("<leader>db", function()
			dap.toggle_breakpoint()
		end, "DAP: Toggle breakpoint")

		nmap("<leader>dB", function()
			local condition = vim.fn.input("Breakpoint condition: ")
			if condition and condition ~= "" then
				dap.set_breakpoint(condition)
			else
				dap.toggle_breakpoint()
			end
		end, "DAP: Conditional breakpoint")

		nmap("<leader>dc", function()
			dap.continue()
		end, "DAP: Continue / Start")

		nmap("<leader>dr", function()
			if dap.restart_frame then
				dap.restart_frame()
			else
				dap.run_last()
			end
		end, "DAP: Restart frame")

		nmap("<leader>dx", function()
			dap.terminate()
		end, "DAP: Terminate")

		nmap("<leader>do", function()
			dap.step_over()
		end, "DAP: Step over")

		nmap("<leader>di", function()
			dap.step_into()
		end, "DAP: Step into")

		nmap("<leader>dO", function()
			dap.step_out()
		end, "DAP: Step out")

		nmap("<leader>dl", function()
			dap.run_last()
		end, "DAP: Run last")

		nmap("<leader>dh", function()
			require("dap.ui.widgets").hover()
		end, "DAP: Hover variables")

		nmap("<leader>dp", function()
			require("dap.ui.widgets").preview()
		end, "DAP: Preview value")

		nmap("<leader>df", function()
			local widgets = require("dap.ui.widgets")
			widgets.centered_float(widgets.frames)
		end, "DAP: Show frames")

		nmap("<leader>ds", function()
			local widgets = require("dap.ui.widgets")
			widgets.centered_float(widgets.scopes)
		end, "DAP: Show scopes")

		nmap("<leader>de", function()
			require("dapui").eval()
		end, "DAP: Evaluate expression")

		map("v", "<leader>de", function()
			require("dapui").eval()
		end, { desc = "DAP: Evaluate selection", silent = true })

		nmap("<leader>du", function()
			require("dapui").toggle()
		end, "DAP: Toggle UI")
	end
end
