-- ~/.config/nvim/lua/plugins/sessions.lua
-- Session management with folke/persistence.nvim

return {
	"folke/persistence.nvim",
	event = "BufReadPre", -- load before buffers open
	opts = {
		dir = vim.fn.stdpath("state") .. "/sessions/", -- where to store sessions
		options = { "buffers", "curdir", "tabpages", "winsize" },
	},

	config = function()
		require("persistence").setup({
			dir = vim.fn.stdpath("state") .. "/sessions/",
			options = { "buffers", "curdir", "tabpages", "winsize" },
		})

		-- Reopen nvim-tree automatically after loading a session
		vim.api.nvim_create_autocmd("User", {
			pattern = "PersistenceLoadPost",
			callback = function()
				local ok, api = pcall(require, "nvim-tree.api")
				if ok then
					api.tree.open()
				end
			end,
		})
	end,

	keys = {
		{
			"<leader>qs",
			function()
				require("persistence").save()
			end,
			desc = "Save session",
		},
		{
			"<leader>ql",
			function()
				require("persistence").load({ last = true })
			end,
			desc = "Load last session",
		},
		{
			"<leader>qd",
			function()
				require("persistence").stop()
			end,
			desc = "Disable persistence",
		},
		{
			"<leader>qq",
			function()
				vim.cmd("wall") -- write all modified buffers
				require("persistence").save()
				vim.cmd("qa") -- quit Neovim
			end,
			desc = "Quit and save session (safe)",
		},
	},
}
