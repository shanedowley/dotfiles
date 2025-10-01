-- ~/.config/nvim/lua/plugins/init.lua
-- Master plugin list with Lazy.nvim
-- Core plugins eager; extras lazy.

return {
	-- ✅ Core (load eagerly at startup)
	{ import = "plugins.cmp" },
	{ import = "plugins.lsp" },
	{ import = "plugins.treesitter" },
	{ import = "plugins.ui" },
	{ import = "plugins.snippets" },
	{ import = "plugins.asm" },
	{ import = "plugins.vimtex" },

	-- ⏱ Lazy-load candidates
	{ import = "plugins.tests", cmd = "TestNearest" },
	{ import = "plugins.autopairs", event = "InsertEnter" },
	{ import = "plugins.telescope", cmd = "Telescope" },
	{ import = "plugins.nvim-tree", cmd = "NvimTreeToggle" },
	{ import = "plugins.filetree", cmd = "NvimTreeToggle" }, -- duplicate wrapper
	{ import = "plugins.lsp_web_ruby", ft = { "ruby" } },
	{ import = "plugins.formatter_web", ft = { "html", "css", "javascript", "typescript" } },
	{ import = "plugins.lint", event = "BufWritePost" },
	{ "nvim-treesitter/playground", cmd = "TSPlaygroundToggle" },
	{ import = "plugins.formatter", event = "BufWritePre" },
	{ import = "plugins.debugger", cmd = { "DapContinue", "DapToggleBreakpoint" } },
	{ import = "plugins.sessions", event = "BufReadPre" },
	{ import = "plugins.whichkey", event = "VeryLazy" },
	{ import = "plugins.editing", event = "InsertEnter" },
	{ import = "plugins.git", event = "BufReadPre" },
	{ import = "plugins.web", ft = { "html", "css", "javascript", "typescript" } },
	{ import = "plugins.debug_js", cmd = { "DapContinue", "DapToggleBreakpoint" } },
	{ import = "plugins.mason", cmd = "Mason" },
	{ import = "plugins.dapui", cmd = { "DapContinue", "DapToggleBreakpoint" } },
	{ import = "plugins.navigation", keys = "<leader><leader>" },
	{ import = "plugins.lsp_ui", event = "LspAttach" },
}
