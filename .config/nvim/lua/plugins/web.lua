-- Front-end editing helpers without duplicate surround/colorizer setup.
return {
	-- Auto-close & auto-rename HTML/JSX/TSX tags
	{
		"windwp/nvim-ts-autotag",
		ft = { "html", "xml", "javascriptreact", "typescriptreact", "javascript", "typescript", "svelte", "vue" },
		config = function()
			require("nvim-ts-autotag").setup({
				opts = {
					enable_close = true,
					enable_rename = true,
					enable_close_on_slash = true,
				},
			})
		end,
	},

	-- Comment toggling: gc (motion), gcc (line), gb (block)
	{
		"numToStr/Comment.nvim",
		keys = {
			{ "gc", mode = { "n", "x" } },
			{ "gcc", mode = "n" },
			{ "gbc", mode = "n" },
		},
		config = function()
			require("Comment").setup()
		end,
	},
}
