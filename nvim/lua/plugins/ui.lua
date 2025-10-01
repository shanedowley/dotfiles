return {
	-- Colorscheme
	{
		"morhetz/gruvbox",
		lazy = false,
		priority = 1000,
		config = function()
			vim.cmd("colorscheme gruvbox")
			vim.cmd("hi Normal guibg=NONE ctermbg=NONE") -- transparent background (optional)
		end,
	},

	-- in plugins/ui.lua or a misc plugin file
	{
		"karb94/neoscroll.nvim",
		event = "VeryLazy",
		config = function()
			require("neoscroll").setup({
				-- Smooth, Mac-style behavior
				easing_function = "sine", -- "sine" | "quadratic" | "cubic"
				hide_cursor = false,
				respect_scrolloff = true,
				stop_eof = true,
				performance_mode = true,
				mappings = { -- animate these motions
					"<C-u>",
					"<C-d>",
					"<C-b>",
					"<C-f>",
					"zt",
					"zz",
					"zb",
					"gg",
					"G",
				},
			})
		end,
	},

	-- silence mini.icons warning
	{ "echasnovski/mini.icons", version = false },

	-- Statusline
	{
		"nvim-lualine/lualine.nvim",
		dependencies = { "nvim-tree/nvim-web-devicons" },
		config = function()
			require("lualine").setup({
				options = {
					theme = "gruvbox",
					section_separators = { left = "", right = "" },
					component_separators = { left = "", right = "" },
				},
				sections = {
					lualine_a = { "mode" },
					lualine_b = { "branch", "diff", "diagnostics" },
					lualine_c = { { "filename", path = 1 } },
					lualine_x = { "encoding", "fileformat", "filetype" },
					lualine_y = { "progress" },
					lualine_z = { "location" },
				},
			})
		end,
	},
	{
		"NvChad/nvim-colorizer.lua",
		config = function()
			require("colorizer").setup({
				filetypes = { "*" }, -- apply everywhere
				user_default_options = {
					RGB = true, -- #RGB
					RRGGBB = true, -- #RRGGBB
					names = true, -- "Blue" or "red"
					RRGGBBAA = true, -- #RRGGBBAA
					rgb_fn = true, -- rgb(0,0,0)
					hsl_fn = true, -- hsl(0, 100%, 50%)
					css = true, -- enable all CSS features: rgb_fn, hsl_fn, names, etc.
					css_fn = true,
				},
			})
		end,
	},
}
