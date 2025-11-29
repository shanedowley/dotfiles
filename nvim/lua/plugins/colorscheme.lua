local themes = {
	{
		name = "django-smooth",
		plugin = "ShaneDowley/nvim-django-smooth",
		dir = vim.fn.stdpath("config") .. "/lua/themes/django-smooth",
	},
	{ name = "gruvbox", plugin = "ellisonleao/gruvbox.nvim" },
	{ name = "tokyonight", plugin = "folke/tokyonight.nvim" },
	{ name = "catppuccin", plugin = "catppuccin/nvim", opts = { flavour = "mocha" } },
	{ name = "rose-pine", plugin = "rose-pine/neovim" },
	{ name = "kanagawa", plugin = "rebelot/kanagawa.nvim" },
}

local function build_theme_plugins()
	local specs = {}

	-- Lush dependency for django-smooth
	table.insert(specs, { "rktjmp/lush.nvim", lazy = true })

	for _, entry in ipairs(themes) do
		local spec = {
			entry.plugin,
			lazy = true,
			priority = 1000,
		}

		if entry.dir then
			spec.dir = entry.dir
		end

		if entry.plugin == "ellisonleao/gruvbox.nvim" then
			spec.config = function()
				require("gruvbox").setup({
					contrast = "soft",
					transparent_mode = false,
				})
			end
		elseif entry.plugin == "folke/tokyonight.nvim" then
			spec.config = function()
				require("tokyonight").setup({
					style = "night",
					transparent = false,
				})
			end
		elseif entry.plugin == "catppuccin/nvim" then
			spec.name = "catppuccin"
			spec.config = function()
				require("catppuccin").setup({
					flavour = "mocha",
					transparent_background = false,
				})
			end
		elseif entry.plugin == "rose-pine/neovim" then
			spec.name = "rose-pine"
			spec.config = function()
				require("rose-pine").setup({
					variant = "auto",
					dark_variant = "main",
					dim_inactive_windows = false,
					extend_background_behind_borders = true,
					styles = {
						bold = true,
						italic = true,
						transparency = false,
					},
				})
			end
		elseif entry.plugin == "rebelot/kanagawa.nvim" then
			spec.config = function()
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
					theme = "wave",
					background = {
						dark = "wave",
						light = "lotus",
					},
				})
			end
		end

		table.insert(specs, spec)
	end

	return specs
end

local function last_theme_path()
	return vim.fn.stdpath("data") .. "/last-theme.txt"
end

local function load_saved_theme(themes_list, default)
	local path = last_theme_path()
	local file = io.open(path, "r")
	if file then
		local name = file:read("*l")
		file:close()
		if name and vim.fn.empty(name) == 0 then
			return name
		end
	end
	return default
end

local function save_theme(name)
	local file = io.open(last_theme_path(), "w")
	if file then
		file:write(name)
		file:close()
	end
end

local function apply_theme(name)
	if not name or name == "" then
		return false
	end
	local ok = pcall(vim.cmd.colorscheme, name)
	if ok then
		vim.g.active_theme = name
	end
	return ok
end

local function theme_names()
	local names = {}
	for _, entry in ipairs(themes) do
		table.insert(names, entry.name)
	end
	return names
end

local function setup_theme_cycle(theme_list)
	local current_index = 1

	local saved = load_saved_theme(theme_list, "django-smooth")
	for idx, name in ipairs(theme_list) do
		if name == saved then
			current_index = idx
			break
		end
	end

	if not apply_theme(theme_list[current_index]) then
		apply_theme("django-smooth")
	end

	vim.keymap.set("n", "<leader>ut", function()
		current_index = current_index % #theme_list + 1
		local theme = theme_list[current_index]
		if apply_theme(theme) then
			save_theme(theme)
			vim.notify("Theme switched to: " .. theme, vim.log.levels.INFO)

			local preset_map = {
				gruvbox = "gruvbox-dark",
				tokyonight = "tokyonight_night",
				catppuccin = "catppuccin-mocha",
			}

			local preset = preset_map[theme]
			if preset then
				local script = string.format(
					[[osascript -e 'tell application "iTerm2" to set color preset of current window to "%s"' ]],
					preset
				)
				vim.fn.jobstart(script, { detach = true })
			end
		else
			vim.notify("Failed to load theme " .. theme, vim.log.levels.WARN)
		end
	end, { desc = "Switch color scheme" })

	local ok_lualine, lualine = pcall(require, "lualine")
	if ok_lualine then
		local theme_indicator = function()
			return " " .. (vim.g.active_theme or theme_list[current_index] or "theme")
		end
		lualine.setup({
			options = { theme = "auto" },
			sections = {
				lualine_a = { "mode" },
				lualine_b = { "branch", "diff", "diagnostics" },
				lualine_c = { "filename" },
				lualine_x = { theme_indicator, "encoding", "filetype" },
				lualine_y = { "progress" },
				lualine_z = { "location" },
			},
		})
	end
end

local M = build_theme_plugins()

table.insert(M, {
	"nvim-lua/plenary.nvim",
	lazy = false,
	priority = 2000,
	dependencies = vim.tbl_map(function(entry)
		return entry.plugin
	end, themes),
	config = function()
		vim.opt.termguicolors = true
		vim.opt.background = "dark"
		setup_theme_cycle(theme_names())
	end,
})

return M
