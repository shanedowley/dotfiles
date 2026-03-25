-- ~/.config/nvim/lua/plugins/markdown.lua
return {
	{
		"iamcco/markdown-preview.nvim",
		cmd = { "MarkdownPreview", "MarkdownPreviewStop", "MarkdownPreviewToggle" },
		ft = { "markdown" },

		-- Prevent yarn.lock modifications on update
		build = "cd app && yarn install --frozen-lockfile",

		init = function()
			vim.g.mkdp_browser = "safari"
			vim.g.mkdp_auto_close = 1
			vim.g.mkdp_refresh_slow = 0
		end,

		config = function()
			vim.keymap.set("n", "<leader>Mp", "<cmd>MarkdownPreviewToggle<CR>", { desc = "Toggle Markdown Preview" })

			local plugin_path = vim.fn.stdpath("data") .. "/lazy/markdown-preview.nvim"
			local build_marker = plugin_path .. "/.mkdp_built"

			if vim.fn.filereadable(build_marker) == 0 then
				local online = vim.fn.system("ping -c 1 github.com > /dev/null 2>&1 && echo online || echo offline")
				local has_yarn = vim.fn.executable("yarn") == 1

				if has_yarn and string.find(online, "online") then
					vim.fn.jobstart(
						{
							"bash",
							"-c",
							"cd " .. plugin_path .. "/app && yarn install --frozen-lockfile && touch " .. build_marker,
						},
						{ detach = true }
					)
				else
					-- Silent skip: this is non-critical and should not pollute startup UX.
				end
			end
		end,
	},
}