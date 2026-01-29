-- Lazy.nvim plugin imports (new keymaps/which-key modules)
return {
	-- ✅ Core (load eagerly at startup)
	{ import = "plugins.cmp" },
	{ import = "plugins.lsp" },
	{ import = "plugins.treesitter" },
	{ import = "plugins.ui" },
	{ import = "plugins.snippets" },
	{ import = "plugins.asm" },
	{ import = "plugins.vimtex" },
	{ import = "plugins.colorscheme" },

	-- ⏱ Lazy-load candidates
	{ import = "plugins.tests", cmd = "TestNearest" },
	{ import = "plugins.editing", event = "InsertEnter" },
	{ import = "plugins.telescope", cmd = "Telescope" },
	{ import = "plugins.nvim_tree", cmd = "NvimTreeToggle" },
	{ import = "plugins.lsp_web_ruby", ft = { "ruby" } },
	{ import = "plugins.formatter_web", ft = { "html", "css", "javascript", "typescript" } },
	{ import = "plugins.lint", event = "BufWritePost" },
	{ "nvim-treesitter/playground", cmd = "TSPlaygroundToggle" },
	{ import = "plugins.formatter", event = "BufWritePre" },
	{ import = "plugins.debug", event = "VeryLazy" },
	{ import = "plugins.sessions", event = "BufReadPre" },
	{ import = "plugins.markdown", ft = { "markdown" } }, -- 🧩 Markdown Preview plugin
	{ import = "plugins.whichkey", event = "VeryLazy" },
	{ import = "plugins.git", event = "BufReadPre" },
	{ import = "plugins.web", ft = { "html", "css", "javascript", "typescript" } },
	{ import = "plugins.mason", cmd = "Mason" },
	{ import = "plugins.navigation", keys = "<leader><leader>" },
	{ import = "plugins.lsp_ui", event = "LspAttach" },
}
