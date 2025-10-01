-- ~/.config/nvim/lua/plugins/web.lua
-- Quality-of-life plugins for front-end editing

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

	-- Surroundings: ys, ds, cs — great for quotes/tags/parentheses
	{
		"kylechui/nvim-surround",
		event = "VeryLazy",
		config = function()
			require("nvim-surround").setup()
		end,
	},

	-- Color preview in CSS/HTML/JS/TS (hex/rgb/hsl, also Tailwind color classes)
	{
		"NvChad/nvim-colorizer.lua",
		event = { "BufReadPre", "BufNewFile" },
		config = function()
			require("colorizer").setup({
				filetypes = {
					"*", -- works for most; you can narrow if you prefer
				},
				user_default_options = {
					names = true,
					RGB = true,
					RRGGBB = true,
					RRGGBBAA = true,
					rgb_fn = true,
					hsl_fn = true,
					css = true,
					css_fn = true,
					mode = "background", -- "foreground" or "virtualtext" are options
					tailwind = true, -- highlight Tailwind color classes
				},
			})
		end,
	},
}
