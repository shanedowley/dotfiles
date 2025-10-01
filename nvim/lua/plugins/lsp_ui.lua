-- ~/.config/nvim/lua/plugins/lsp_ui.lua
return {
	{
		"nvimdev/lspsaga.nvim",
		event = "LspAttach",
		config = function()
			require("lspsaga").setup({
				-- Minimal config to start, we’ll extend step by step
				ui = {
					border = "rounded",
					title = true,
					code_action = "💡",
				},
				symbol_in_winbar = {
					enable = false, -- we can turn this on later if you want breadcrumbs
				},
			})
		end,
		dependencies = {
			"nvim-treesitter/nvim-treesitter", -- for syntax parsing
			"nvim-tree/nvim-web-devicons", -- icons
		},
	},
}
