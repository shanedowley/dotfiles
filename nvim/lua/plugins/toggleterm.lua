return {
	"akinsho/toggleterm.nvim",
	version = "*",
	config = function()
		require("toggleterm").setup({
			size = 15,
			open_mapping = [[<C-\>]], -- Ctrl + \ to toggle
			hide_numbers = true,
			shade_terminals = true,
			shading_factor = 2,
			start_in_insert = true,
			insert_mappings = true,
			terminal_mappings = true,
			persist_size = true,
			direction = "float", -- use a floating drop-down in Neovide
			close_on_exit = true,
			shell = vim.o.shell,
		})
		----------------------------------------------------
		-- Quake-style drop-down terminal on <F12>
		----------------------------------------------------
		local Terminal = require("toggleterm.terminal").Terminal

		-- size + position for the drop-down feel
		local function quake_opts()
			local cols = vim.o.columns
			local lines = vim.o.lines

			local width = math.floor(cols * 0.9) -- 90% of screen width
			local height = math.floor(lines * 0.4) -- 40% of screen height
			local col = math.floor((cols - width) / 2) -- centred horizontally
			local row = 1 -- drop down from top

			return {
				border = "curved",
				width = width,
				height = height,
				col = col,
				row = row,
			}
		end

		local quake_term = Terminal:new({
			cmd = vim.o.shell, -- your default shell
			hidden = true,
			direction = "float",
			float_opts = quake_opts(),
		})

		function _quake_toggle()
			quake_term:toggle()
		end

		-- Toggle with F12 in NORMAL and TERMINAL modes
		vim.keymap.set({ "n", "t" }, "<F12>", _quake_toggle, {
			noremap = true,
			silent = true,
			desc = "Toggle Quake terminal",
		})

		----------------------------------------------------
		-- (Optional) nice terminal navigation
		----------------------------------------------------
		vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]], { silent = true })
		vim.keymap.set("t", "<C-h>", [[<C-\><C-n><C-w>h]], { silent = true })
		vim.keymap.set("t", "<C-j>", [[<C-\><C-n><C-w>j]], { silent = true })
		vim.keymap.set("t", "<C-k>", [[<C-\><C-n><C-w>k]], { silent = true })
		vim.keymap.set("t", "<C-l>", [[<C-\><C-n><C-w>l]], { silent = true })

		----------------------------------------------------
		-- Better keymaps inside terminal mode
		----------------------------------------------------
		local term_opts = { noremap = true, silent = true }
		vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]], term_opts)
		vim.keymap.set("t", "<C-h>", [[<C-\><C-n><C-w>h]], term_opts)
		vim.keymap.set("t", "<C-j>", [[<C-\><C-n><C-w>j]], term_opts)
		vim.keymap.set("t", "<C-k>", [[<C-\><C-n><C-w>k]], term_opts)
		vim.keymap.set("t", "<C-l>", [[<C-\><C-n><C-w>l]], term_opts)

		----------------------------------------------------
		-- Rust / Cargo helpers – buffer-local for Rust only
		----------------------------------------------------
		vim.api.nvim_create_autocmd("FileType", {
			pattern = "rust",
			callback = function(ev)
				local opts = { noremap = true, silent = true, buffer = ev.buf }

				-- Cargo run
				vim.keymap.set(
					"n",
					"<leader>rr",
					"<cmd>TermExec cmd='cargo run'<CR>",
					vim.tbl_extend("force", opts, { desc = "Cargo run" })
				)

				-- Cargo build
				vim.keymap.set(
					"n",
					"<leader>rb",
					"<cmd>TermExec cmd='cargo build'<CR>",
					vim.tbl_extend("force", opts, { desc = "Cargo build" })
				)

				-- Cargo test
				vim.keymap.set(
					"n",
					"<leader>rt",
					"<cmd>TermExec cmd='cargo test'<CR>",
					vim.tbl_extend("force", opts, { desc = "Cargo test" })
				)
			end,
		})
	end,
}
