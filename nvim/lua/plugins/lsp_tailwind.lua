-- lua/plugins/lsp_tailwind.lua
return {
	"neovim/nvim-lspconfig",
	dependencies = { "williamboman/mason-lspconfig.nvim" },
	config = function()
		local lspconfig = require("lspconfig")
		local util = require("lspconfig.util")

		lspconfig.tailwindcss.setup({
			cmd = { "tailwindcss-language-server", "--stdio" },
			filetypes = {
				"html",
				"htmldjango", -- for Jekyll/Liquid templates
				"css",
				"javascript",
				"javascriptreact",
				"typescript",
				"typescriptreact",
				"vue",
				"svelte",
			},
			root_dir = util.root_pattern(
				"tailwind.config.js",
				"tailwind.config.cjs",
				"tailwind.config.mjs",
				"tailwind.config.ts",
				"postcss.config.js",
				"package.json"
			),
			settings = {
				tailwindCSS = {
					experimental = {
						classRegex = {
							-- Support for Jekyll/Liquid style templates
							{ 'class\\s*=\\s*"([^"]*)"', 1 },
							{ "class\\s*=\\s*'([^']*)'", 1 },
						},
					},
				},
			},
		})
	end,
}
