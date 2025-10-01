return {
	"lewis6991/gitsigns.nvim",
	event = { "BufReadPre", "BufNewFile" },
	config = function()
		require("gitsigns").setup({
			signs = {
				add = { text = "▎" },
				change = { text = "▎" },
				delete = { text = "契" },
				topdelete = { text = "契" },
				changedelete = { text = "▎" },
				untracked = { text = "▎" },
			},
			signcolumn = true, -- show signs in number column
			numhl = false, -- no highlight on line numbers
			linehl = false, -- no highlight on full line
			word_diff = false, -- disable word diff by default
			current_line_blame = true, -- show git blame for current line
			current_line_blame_opts = {
				virt_text = true,
				virt_text_pos = "eol", -- end of line
				delay = 300,
				ignore_whitespace = false,
			},
			current_line_blame_formatter = "<author>, <author_time:%Y-%m-%d> - <summary>",
		})

		-- Keymaps for git hunk actions
		vim.keymap.set(
			"n",
			"]c",
			"&diff ? ']c' : '<cmd>Gitsigns next_hunk<CR>'",
			{ expr = true, desc = "Next git hunk" }
		)
		vim.keymap.set(
			"n",
			"[c",
			"&diff ? '[c' : '<cmd>Gitsigns prev_hunk<CR>'",
			{ expr = true, desc = "Prev git hunk" }
		)
		vim.keymap.set("n", "<leader>hs", "<cmd>Gitsigns stage_hunk<CR>", { desc = "Stage hunk" })
		vim.keymap.set("n", "<leader>hr", "<cmd>Gitsigns reset_hunk<CR>", { desc = "Reset hunk" })
		vim.keymap.set("n", "<leader>hb", "<cmd>Gitsigns blame_line<CR>", { desc = "Blame line" })
		vim.keymap.set("n", "<leader>hd", "<cmd>Gitsigns diffthis<CR>", { desc = "Diff file" })
	end,
}
