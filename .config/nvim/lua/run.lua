-- ~/.config/nvim/lua/run.lua
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



