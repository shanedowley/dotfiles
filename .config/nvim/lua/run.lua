local M = {}

-- Safe accessor so requiring toggleterm doesn't explode if it's not loaded yet
local function get_terminal()
	local ok, term_mod = pcall(require, "toggleterm.terminal")
	if not ok then
		vim.notify("toggleterm not available (is it installed / loaded?)", vim.log.levels.WARN, { title = "run.lua" })
		return nil
	end
	return term_mod.Terminal
end

local function load_plugin(name)
	pcall(function()
		local ok, lazy = pcall(require, "lazy")
		if ok then
			lazy.load({ plugins = { name } })
		end
	end)
end

function M.build_and_run_current_cpp()
	local Terminal = get_terminal()
	if not Terminal then
		return
	end

	vim.cmd("w")

	local file = vim.fn.expand("%:p")
	local base = vim.fn.expand("%:t:r")
	local dir = vim.fn.expand("%:p:h")

	local cmd = string.format(
		"cd %q && g++ -std=c++20 -O2 %q -o %q && ./%q; echo ''; echo '--- Press any key to close ---'; read -n 1",
		dir,
		file,
		base,
		base
	)

	Terminal:new({
		cmd = cmd,
		direction = "float",
		close_on_exit = false,
	}):toggle()
end

function M.build_and_debug_current_c_cpp()
	vim.cmd("w")

	local file = vim.fn.expand("%:p")
	local base = vim.fn.expand("%:t:r")
	local dir = vim.fn.expand("%:p:h")
	local ft = vim.bo.filetype

	if ft ~= "c" and ft ~= "cpp" and ft ~= "cc" and ft ~= "cxx" then
		vim.notify("Build+Debug is only supported for C/C++ buffers", vim.log.levels.WARN, { title = "run.lua" })
		return
	end

	local compiler
	local cmd

	if ft == "c" then
		compiler = "clang"
		cmd = { compiler, "-g", "-O0", file, "-o", base .. "_debug" }
	else
		compiler = "clang++"
		cmd = { compiler, "-std=c++20", "-g", "-O0", file, "-o", base .. "_debug" }
	end

	if vim.fn.executable(compiler) ~= 1 then
		vim.notify(("Compiler not found: %s"):format(compiler), vim.log.levels.ERROR, { title = "run.lua" })
		return
	end

	local result = vim.system(cmd, { cwd = dir, text = true }):wait()

	if result.code ~= 0 then
		local output = (result.stderr and result.stderr ~= "") and result.stderr or (result.stdout or "")
		vim.notify("Build failed:\n" .. output, vim.log.levels.ERROR, { title = "Build & Debug" })
		return
	end

	local program = dir .. "/" .. base .. "_debug"

	if vim.fn.filereadable(program) ~= 1 then
		vim.notify("Debug binary not found after build: " .. program, vim.log.levels.ERROR, { title = "Build & Debug" })
		return
	end

	load_plugin("nvim-dap")
	load_plugin("nvim-dap-ui")

	local ok_dap, dap = pcall(require, "dap")
	if not ok_dap then
		vim.notify("nvim-dap could not be loaded", vim.log.levels.ERROR, { title = "Build & Debug" })
		return
	end

	pcall(function()
		require("dapui").open()
	end)

	dap.run({
		name = "Build & Debug current C/C++ file",
		type = "cpp",
		request = "launch",
		program = program,
		cwd = dir,
		stopOnEntry = false,
		args = {},
		initCommands = {
			"breakpoint set --name main",
		},
	})

	vim.notify(
		"Built debug binary and launched DAP: " .. base .. "_debug",
		vim.log.levels.INFO,
		{ title = "Build & Debug" }
	)
end

function M.build_project_with_make()
	local Terminal = get_terminal()
	if not Terminal then
		return
	end

	local cwd = vim.loop.cwd()
	local cmd = string.format("cd %q && make; echo ''; echo '--- Press any key to close ---'; read -n 1", cwd)

	Terminal:new({
		cmd = cmd,
		direction = "horizontal",
		size = 15,
		close_on_exit = false,
	}):toggle()
end

return M

