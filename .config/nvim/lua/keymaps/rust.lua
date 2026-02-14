local group = vim.api.nvim_create_augroup("RustCargoTermExec", { clear = true })

vim.api.nvim_create_autocmd("FileType", {
	group = group,
	pattern = "rust",
	callback = function(ev)
		-- Ensure toggleterm is available so :TermExec exists
		pcall(function()
			require("lazy").load({ plugins = { "toggleterm.nvim" } })
		end)

		local opts = { noremap = true, silent = true, buffer = ev.buf }

		vim.keymap.set(
			"n",
			"<leader>rr",
			"<cmd>TermExec cmd='cargo run'<CR>",
			vim.tbl_extend("force", opts, { desc = "Cargo run" })
		)

		vim.keymap.set(
			"n",
			"<leader>rb",
			"<cmd>TermExec cmd='cargo build'<CR>",
			vim.tbl_extend("force", opts, { desc = "Cargo build" })
		)

		vim.keymap.set(
			"n",
			"<leader>rt",
			"<cmd>TermExec cmd='cargo test'<CR>",
			vim.tbl_extend("force", opts, { desc = "Cargo test" })
		)
	end,
})
