return {
	-- Gruvbox (default)
	{
		"ellisonleao/gruvbox.nvim",
		lazy = false,
		priority = 1000,
		config = function()
			require("gruvbox").setup({
				contrast = "soft",
				transparent_mode = false,
			})
		end,
	},

	-- Tokyonight
	{
		"folke/tokyonight.nvim",
		lazy = true,
		priority = 999,
		config = function()
			require("tokyonight").setup({
				style = "night",
				transparent = false,
			})
		end,
	},

	-- Catppuccin
	{
		"catppuccin/nvim",
		name = "catppuccin",
		lazy = true,
		priority = 998,
		config = function()
			require("catppuccin").setup({
				flavour = "mocha",
				transparent_background = false,
			})
		end,
	},

	-- Theme switcher + persistence + lualine integration
	{
		"nvim-lua/plenary.nvim",
		lazy = true,
		config = function()
			local themes = { "gruvbox", "tokyonight", "catppuccin" }
			local current = 1
			local save_path = vim.fn.stdpath("data") .. "/last-theme.txt"

			-- Helper: save theme
			local function save_theme(name)
				local f = io.open(save_path, "w")
				if f then
					f:write(name)
					f:close()
				end
			end

			-- Helper: load theme
			local function load_theme()
				local f = io.open(save_path, "r")
				if f then
					local theme = f:read("*l")
					f:close()
					if theme and pcall(vim.cmd, "colorscheme " .. theme) then
						vim.g.active_theme = theme
						return theme
					end
				end
				vim.cmd("colorscheme gruvbox")
				vim.g.active_theme = "gruvbox"
				return "gruvbox"
			end

			-- Load last theme at startup
			local last = load_theme()
			for i, t in ipairs(themes) do
				if t == last then
					current = i
				end
			end

			-- Theme cycling
			vim.keymap.set("n", "<leader>ut", function()
				current = current % #themes + 1
				local theme = themes[current]
				vim.cmd("colorscheme " .. theme)
				vim.g.active_theme = theme
				save_theme(theme)
				vim.notify("Theme switched to: " .. theme, vim.log.levels.INFO)
			end, { desc = "Switch color scheme" })

			-- Integrate theme name into Lualine
			local ok, lualine = pcall(require, "lualine")
			if ok then
				local theme_name = function()
					return " " .. (vim.g.active_theme or "gruvbox")
				end
				lualine.setup({
					options = { theme = vim.g.active_theme or "gruvbox" },
					sections = {
						lualine_a = { "mode" },
						lualine_b = { "branch", "diff", "diagnostics" },
						lualine_c = { "filename" },
						lualine_x = { theme_name, "encoding", "filetype" },
						lualine_y = { "progress" },
						lualine_z = { "location" },
					},
				})
			end
		end,
	},
}
