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

	-- Django Smooth
	{
		"rktjmp/lush.nvim", -- dependency for writing Lua colorschemes
		lazy = true,
	},
	{
		"ShaneDowley/nvim-django-smooth",
		dir = vim.fn.stdpath("config") .. "/lua/themes/django-smooth",
		lazy = false,
		priority = 1000,
		config = function()
			vim.opt.termguicolors = true
			vim.opt.background = "dark"
			vim.cmd.colorscheme("django-smooth")
		end,
	},

	----------------------------------------------------------------------
	-- 🌸 ROSE-PINE
	----------------------------------------------------------------------
	{
		"rose-pine/neovim",
		name = "rose-pine",
		lazy = false,
		priority = 1000,
		config = function()
			require("rose-pine").setup({
				variant = "auto", -- "auto", "main", "moon", "dawn"
				dark_variant = "main",
				dim_inactive_windows = false,
				extend_background_behind_borders = true,
				styles = {
					bold = true,
					italic = true,
					transparency = false,
				},
			})
		end,
	},

	----------------------------------------------------------------------
	-- 🌊 KANAGAWA
	----------------------------------------------------------------------
	{
		"rebelot/kanagawa.nvim",
		lazy = false,
		priority = 1000,
		config = function()
			require("kanagawa").setup({
				compile = false,
				undercurl = true,
				commentStyle = { italic = true },
				functionStyle = { bold = true },
				keywordStyle = { italic = true },
				statementStyle = { bold = true },
				typeStyle = { italic = true },
				transparent = false,
				dimInactive = false,
				theme = "wave", -- "wave", "dragon", "lotus"
				background = {
					dark = "wave",
					light = "lotus",
				},
			})
		end,
	},

	-- Theme switcher + persistence + lualine integration
	{
		"nvim-lua/plenary.nvim",
		lazy = true,
		config = function()
			local themes = { "django-smooth", "gruvbox", "tokyonight", "catppuccin", "rose-pine", "kanagawa" }
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

			-- Theme cycling with iTerm2 sync
			vim.keymap.set("n", "<leader>ut", function()
				current = current % #themes + 1
				local theme = themes[current]
				vim.cmd("colorscheme " .. theme)
				vim.g.active_theme = theme
				save_theme(theme)

				-- Notify Neovim
				vim.notify("Theme switched to: " .. theme, vim.log.levels.INFO)

				-- iTerm2 preset names must exactly match your imported ones
				local preset_map = {
					gruvbox = "gruvbox-dark",
					tokyonight = "tokyonight_night",
					catppuccin = "catppuccin-mocha",
				}

				local preset = preset_map[theme]
				if preset then
					local script = string.format(
						[[osascript -e 'tell application "iTerm2" to set color preset of current window to "%s"']],
						preset
					)
					vim.fn.jobstart(script, { detach = true })
				end
			end, { desc = "Switch color scheme (with iTerm2 sync)" })

			-- Integrate theme name into Lualine
			local ok, lualine = pcall(require, "lualine")
			if ok then
				local theme_name = function()
					return " " .. (vim.g.active_theme or "gruvbox")
				end
				lualine.setup({
					options = { theme = "auto" },
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
