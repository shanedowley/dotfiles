-- turn on Neovim's module cache
if vim.loader then
	vim.loader.enable()
end

-- Silence vim.tbl_islist deprecation on 0.10+ by delegating to vim.islist
if vim.tbl_islist and vim.islist then
	vim.tbl_islist = vim.islist
end

-- Ensure filetype detection is on
vim.cmd("filetype plugin indent on")

-- Set <Leader> key
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Ensure timeouts are sane
vim.o.timeout = true
vim.o.timeoutlen = 300 -- 300ms for key sequences

-- ──────────────────────────────────────────────
-- 🪟 Neovide GUI Configuration (macOS)
-- ──────────────────────────────────────────────
if vim.g.neovide then
	-- Font and UI scaling
	vim.o.guifont = "FiraCode Nerd Font Mono:h15" -- use any installed font
	vim.g.neovide_scale_factor = 1.0 -- overall zoom; adjust with Cmd+Plus/Minus

	-- Cursor animations
	vim.g.neovide_cursor_animation_length = 0.05
	vim.g.neovide_cursor_trail_size = 0.3
	vim.g.neovide_cursor_antialiasing = true
	vim.g.neovide_cursor_vfx_mode = "railgun" -- or "torpedo", "sonicboom", "wireframe"

	-- Transparency and blur
	vim.g.neovide_opacity = 0.96
	vim.g.neovide_window_blurred = true

	-- macOS-style keymaps
	vim.g.neovide_input_macos_option_key_is_meta = "only_left"

	-- Remember size between launches
	vim.g.neovide_remember_window_size = true

	-- Custom keybindings (optional)
	vim.keymap.set("n", "<D-s>", ":w<CR>") -- Cmd+S to save
	vim.keymap.set("v", "<D-c>", '"+y') -- Cmd+C to copy
	vim.keymap.set("n", "<D-v>", '"+P') -- Cmd+V to paste in normal mode
	vim.keymap.set("i", "<D-v>", '<ESC>"+Pli') -- Cmd+V in insert mode
end

-- 🪟 Dynamic Neovide window title (modern method)
if vim.g.neovide then
	-- enable Neovim's title reporting
	vim.o.title = true

	-- function to update the title
	local function update_title()
		local cwd = vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
		local file = vim.fn.expand("%:t")
		local title

		if file ~= "" then
			title = string.format("nvim — %s/%s", cwd, file)
		else
			title = string.format("nvim — %s", cwd)
		end

		vim.o.titlestring = title
	end

	-- run once at startup
	update_title()

	-- update on file or directory changes
	vim.api.nvim_create_autocmd({ "BufEnter", "DirChanged" }, {
		callback = update_title,
	})
end

-- UI/UX tweaks
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.mouse = "a"
vim.opt.clipboard = "unnamedplus"
vim.opt.termguicolors = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.smartindent = true
vim.opt.splitbelow = true
vim.opt.splitright = true

-- Mouse + focus/hover behavior
vim.opt.mouse = "a" -- enable mouse everywhere
vim.opt.mousemodel = "extend" -- extend selection with mouse
vim.opt.mousehide = true -- hide mouse cursor when typing
vim.opt.mousemoveevent = true -- send mouse-move events to Neovim
vim.opt.mousefocus = true -- focus the split under the mouse
vim.opt.mousemodel = "popup" -- use popup for mouse clicks
vim.opt.mousescroll = "ver:2,hor:6" -- finer trackpad wheel steps
vim.opt.scrolloff = 4 -- keep context lines visible

-- Optional (if supported by your nvim): tune scroll steps
pcall(function()
	vim.opt.mousescroll = "ver:3,hor:6"
end)

-- ✅ Load keymaps (we will recreate this file next)
require("keymaps")

-- Load Lazy.nvim and plugin specs
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
	vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"https://github.com/folke/lazy.nvim.git",
		"--branch=stable",
		lazypath,
	})
end
vim.opt.rtp:prepend(lazypath)

-- Set up Lazy and load plugins
local plugin_spec = require("plugins")
require("lazy").setup(plugin_spec)

-- Load Codex local integration
require("codex").setup()

-- Soft wrap for coding
vim.opt.wrap = true -- enable visual wrap
vim.opt.linebreak = true -- wrap at word boundaries

vim.opt.list = true
vim.opt.listchars = {
	eol = "↴", -- end of line
	tab = "→ ", -- tab shown as arrow + space
	trail = "·", -- trailing space as a middle dot
	extends = "⟩", -- when text extends off screen
	precedes = "⟨", -- when text continues to the left
	nbsp = "␣", -- non-breaking space
}
vim.opt.cursorline = true
vim.opt.showmode = false

-- Line numbers
vim.opt.number = true -- absolute line numbers
vim.opt.relativenumber = true -- relative numbers (good for motions)

-- Sign column (for git/lsp markers)
vim.opt.signcolumn = "yes" -- always show, avoids text shifting

-- Search tweaks
vim.opt.ignorecase = true -- ignore case when searching...
vim.opt.smartcase = true -- ...unless search has capitals

-- Scrolling comfort
vim.opt.scrolloff = 8 -- keep 8 lines visible above/below cursor
vim.opt.sidescrolloff = 8 -- same for left/right scrolling

-- Splits
vim.opt.splitbelow = true -- horizontal splits open below
vim.opt.splitright = true -- vertical splits open to the right

-- Convert PDF -> Plain Text with Poppler (pdftotext)
vim.api.nvim_create_user_command("PDFtoText", function(opts)
	local input = opts.args
	if input == "" then
		print("Usage: :PDFtoText <file.pdf>")
		return
	end

	-- Expand to absolute path
	local infile = vim.fn.fnamemodify(input, ":p")
	if vim.fn.filereadable(infile) == 0 then
		print("PDFtoText: file not found -> " .. infile)
		return
	end

	-- Temporary output file
	local tmpfile = vim.fn.tempname() .. ".txt"

	-- Run Poppler's pdftotext
	local cmd = { "pdftotext", infile, tmpfile }
	local output = vim.fn.system(cmd)

	if vim.v.shell_error ~= 0 then
		print("PDFtoText: conversion failed -> " .. output)
		return
	end

	-- Open converted file in Neovim
	vim.cmd("edit " .. tmpfile)
end, {
	nargs = 1,
	complete = "file",
	desc = "Convert PDF to plain text and open in Neovim",
})

-- Add your local theme folder to runtimepath
vim.opt.rtp:append(vim.fn.stdpath("config") .. "/lua/themes/django-smooth")
-- 🖌️ Sync iTerm2 color preset with Neovim theme
vim.api.nvim_create_autocmd("ColorScheme", {
	callback = function()
		local theme = vim.g.colors_name

		-- Map Neovim theme names to matching iTerm2 preset names
		local theme_map = {
			["gruvbox"] = "Gruvbox Dark",
			["tokyonight"] = "Tokyo Night Storm",
			["catppuccin"] = "Catppuccin",
			["rose-pine"] = "Rosé Pine (Main)",
			["kanagawa"] = "Kanagawa Wave",
		}

		if theme and #theme > 0 then
			local preset = theme_map[theme] or theme
			vim.fn.jobstart({ "setiterm_theme", preset }, { detach = true })
		end
	end,
	desc = "Sync iTerm2 preset with active Neovim colorscheme",
})

-- Convert PDF -> Markdown using pdftotext + pandoc
vim.api.nvim_create_user_command("PDFtoMd", function(opts)
	local input = opts.args
	if input == "" then
		print("Usage: :PDFtoMd <file.pdf>")
		return
	end

	local infile = vim.fn.fnamemodify(input, ":p")
	if vim.fn.filereadable(infile) == 0 then
		print("PDFtoMd: file not found -> " .. infile)
		return
	end

	local tmpfile = vim.fn.tempname() .. ".md"

	-- Run pipeline: pdftotext -> pandoc
	local cmd = string.format(
		"pdftotext -layout %s - | pandoc -f markdown -t markdown -o %s",
		vim.fn.shellescape(infile),
		vim.fn.shellescape(tmpfile)
	)

	local output = vim.fn.system(cmd)

	if vim.v.shell_error ~= 0 then
		print("PDFtoMd: conversion failed -> " .. output)
		return
	end

	-- Open Markdown in Neovim
	vim.cmd("edit " .. tmpfile)
end, {
	nargs = 1,
	complete = "file",
	desc = "Convert PDF to Markdown and open in Neovim",
})

-- Custom user commands
vim.api.nvim_create_user_command("RmApp", function()
	vim.cmd("terminal rm-app")
end, {
	desc = "Safely uninstall a macOS app with logs",
})

-- Keymap for RmApp command
vim.keymap.set("n", "<leader>ua", ":RmApp<CR>", { desc = "Uninstall macOS app" })
