return {
	"akinsho/toggleterm.nvim",
	version = "*",
	config = function()
		local ok_tt, toggleterm = pcall(require, "toggleterm")
		if not ok_tt then
			vim.notify("toggleterm not available", vim.log.levels.WARN)
			return
		end

		toggleterm.setup({
			size = 15,
			open_mapping = [[<C-\>]],
			hide_numbers = true,
			shade_terminals = true,
			shading_factor = 2,
			start_in_insert = true,
			insert_mappings = true,
			terminal_mappings = true,
			persist_size = true,
			direction = "float",
			float_opts = { border = "rounded" },
			close_on_exit = false,
			shell = vim.o.shell,
		})

		-- -------------------------------
		-- Quake-style floating terminal
		-- -------------------------------
		local ok_term, term_mod = pcall(require, "toggleterm.terminal")
		if not ok_term or not term_mod or not term_mod.Terminal then
			vim.notify("toggleterm.terminal.Terminal not available", vim.log.levels.WARN)
			return
		end
		local Terminal = term_mod.Terminal

		local function quake_opts()
			local cols = vim.o.columns
			local lines = vim.o.lines
			local width = math.floor(cols * 0.9)
			local height = math.floor(lines * 0.4)
			local col = math.floor((cols - width) / 2)

			return {
				border = "curved",
				width = width,
				height = height,
				col = col,
				row = 1,
			}
		end

		local quake_term = Terminal:new({
			cmd = vim.o.shell,
			hidden = true,
			direction = "float",
			float_opts = quake_opts(), -- MUST be a table (not a function)
			close_on_exit = false,
		})

		local function quake_toggle()
			-- refresh size each time (Neovide resize etc.)
			quake_term.float_opts = quake_opts()
			quake_term:toggle()
		end

		vim.keymap.set({ "n", "t" }, "<leader>tt", quake_toggle, {
			noremap = true,
			silent = true,
			desc = "Toggle Quake-style terminal",
		})
	end,
}
