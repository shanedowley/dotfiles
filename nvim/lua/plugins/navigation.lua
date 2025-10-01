-- ~/.config/nvim/lua/plugins/navigation.lua
return {
	{
		"phaazon/hop.nvim",
		branch = "v2",
		config = function()
			require("hop").setup({ keys = "etovxqpdygfblzhckisuran" })

			local hop = require("hop")
			local directions = require("hop.hint").HintDirection

			-- Quick HTML/CSS jump keymaps
			vim.keymap.set("n", "<leader>ac", ":edit styles.css<CR>", { desc = "Go to CSS file" })
			vim.keymap.set("n", "<leader>ah", ":edit index.html<CR>", { desc = "Go to HTML file" })
		end,
	},
}
