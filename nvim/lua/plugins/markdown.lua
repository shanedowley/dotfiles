return {
	{
		"iamcco/markdown-preview.nvim",
		ft = { "markdown" }, -- load only for markdown files
		build = function()
			vim.fn["mkdp#util#install"]() -- installs the Node.js helper
		end,
		config = function()
			-- Browser to open preview in (set to "safari", "chrome", or "firefox")
			vim.g.mkdp_browser = "safari"

			-- Auto-close preview when buffer is closed
			vim.g.mkdp_auto_close = 1

			-- Refresh preview automatically on save
			vim.g.mkdp_refresh_slow = 0

			-- Keymap: toggle preview
			vim.keymap.set("n", "<leader>Mp", "<cmd>MarkdownPreviewToggle<CR>", { desc = "Toggle Markdown Preview" })
		end,
	},
}
