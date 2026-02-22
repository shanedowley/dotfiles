-- ~/.config/nvim/lua/plugins/colorscheme.lua
local themes = {
	{ name = "tokyonight", repo = "folke/tokyonight.nvim" },
	{ name = "gruvbox", repo = "ellisonleao/gruvbox.nvim" },
	{ name = "catppuccin", repo = "catppuccin/nvim" },
	{ name = "rose-pine", repo = "rose-pine/neovim" },
	{ name = "kanagawa", repo = "rebelot/kanagawa.nvim" },

	-- keep it, but we won't default to it
	{
		name = "django-smooth",
		repo = "ShaneDowley/nvim-django-smooth",
		dir = vim.fn.stdpath("config") .. "/lua/themes/django-smooth",
	},
}

local M = {}

-- Lush dependency for django-smooth (only if/when needed)
table.insert(M, { "rktjmp/lush.nvim", lazy = true })

for _, t in ipairs(themes) do
	local spec = {
		t.repo,
		name = t.name, -- THIS is the key your theme loader should use
		lazy = true,
		priority = 1000,
	}

	if t.dir then
		spec.dir = t.dir
	end

	if t.name == "tokyonight" then
		spec.opts = { style = "night", transparent = false }
		spec.config = function(_, opts)
			require("tokyonight").setup(opts)
		end
	elseif t.name == "gruvbox" then
		spec.opts = { contrast = "soft", transparent_mode = false }
		spec.config = function(_, opts)
			require("gruvbox").setup(opts)
		end
	elseif t.name == "catppuccin" then
		spec.opts = { flavour = "mocha", transparent_background = false }
		spec.config = function(_, opts)
			require("catppuccin").setup(opts)
		end
	elseif t.name == "rose-pine" then
		spec.opts = {
			variant = "auto",
			dark_variant = "main",
			dim_inactive_windows = false,
			extend_background_behind_borders = true,
			styles = { bold = true, italic = true, transparency = false },
		}
		spec.config = function(_, opts)
			require("rose-pine").setup(opts)
		end
	elseif t.name == "kanagawa" then
		spec.opts = {
			compile = false,
			undercurl = true,
			commentStyle = { italic = true },
			functionStyle = { bold = true },
			keywordStyle = { italic = true },
			statementStyle = { bold = true },
			typeStyle = { italic = true },
			transparent = false,
			dimInactive = false,
			theme = "wave",
			background = { dark = "wave", light = "lotus" },
		}
		spec.config = function(_, opts)
			require("kanagawa").setup(opts)
		end
	end

	table.insert(M, spec)
end

return M
