-- ~/.config/nvim/lua/plugins/mason.lua
return {
	{
		"williamboman/mason.nvim",
		build = ":MasonUpdate",
		config = function()
			require("mason").setup({
				ui = {
					border = "rounded",
					icons = {
						package_installed = "✓",
						package_pending = "➜",
						package_uninstalled = "✗",
					},
				},
			})
		end,
	},

	{
		"williamboman/mason-lspconfig.nvim",
		dependencies = { "williamboman/mason.nvim" },
		config = function()
			require("mason-lspconfig").setup({
				ensure_installed = {
					-- Frontend / Web
					"html",
					"cssls",
					"jsonls",
					"ts_ls", -- new name for tsserver
					"emmet_ls",
					"tailwindcss",
					"rust_analyzer",
					-- Backend
					"ruby_lsp",
					"clangd",
					"lua_ls",
					"rust_analyzer",
				},
				automatic_installation = true,
			})
		end,
	},

	{
		"jay-babu/mason-nvim-dap.nvim",
		dependencies = { "williamboman/mason.nvim", "mfussenegger/nvim-dap" },
		config = function()
			require("mason-nvim-dap").setup({
				ensure_installed = {
					"js-debug-adapter", -- JavaScript/TypeScript debugger
					"chrome-debug-adapter", -- Optional: debugging in Chrome
					"node-debug2-adapter", -- Optional: older Node.js debugger
				},
				automatic_installation = true,
			})
		end,
	},
}
