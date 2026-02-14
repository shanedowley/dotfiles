-- lua/plugins/lsp_tailwind.lua
return {
	"neovim/nvim-lspconfig",
	-- Mason is not installed in this sandbox, so we drop the mason‑lspconfig
	-- dependency. Tailwind LSP works fine without it.
	dependencies = {},
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
