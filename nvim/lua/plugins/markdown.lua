-- ~/.config/nvim/lua/plugins/markdown.lua
return {
	{
		"iamcco/markdown-preview.nvim",
		cmd = { "MarkdownPreview", "MarkdownPreviewStop", "MarkdownPreviewToggle" },
		ft = { "markdown" },
		build = "cd app && npm install",
		init = function()
			vim.g.mkdp_browser = "safari"
			vim.g.mkdp_auto_close = 1
			vim.g.mkdp_refresh_slow = 0
		end,
		config = function()
			-- keymap
			vim.keymap.set("n", "<leader>Mp", "<cmd>MarkdownPreviewToggle<CR>", { desc = "Toggle Markdown Preview" })

			-- 🧩 Auto rebuild if plugin gets updated
			local plugin_path = vim.fn.stdpath("data") .. "/lazy/markdown-preview.nvim"
			local build_marker = plugin_path .. "/.mkdp_built"

			if vim.fn.filereadable(build_marker) == 0 then
				vim.fn.jobstart(
					{ "bash", "-c", "cd " .. plugin_path .. "/app && npm install && touch " .. build_marker },
					{ detach = true }
				)
			end
		end,
	},
}
