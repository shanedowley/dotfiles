-- ~/.config/nvim/init.lua

-- Leader keys
vim.g.mapleader = " "
vim.g.maplocalleader = " "

local function safe_require(mod)
	local ok, m = pcall(require, mod)
	if ok then
		return m
	end
	vim.schedule(function()
		vim.notify(("safe_require failed: %s\n%s"):format(mod, m), vim.log.levels.WARN)
	end)
	return nil
end

-- Standard macOS XDG layout
-- data  = ~/.local/share/nvim
-- state = ~/.local/state/nvim
-- cache = ~/.cache/nvim

vim.o.swapfile = true
vim.o.shada = "!,'100,<50,s10,h"

-- Silence `vim.tbl_islist` deprecation on 0.10+.
if vim.tbl_islist and vim.islist then
	vim.tbl_islist = vim.islist
end

-- Ensure filetype detection is on
vim.cmd("filetype plugin indent on")

-- Timeouts
vim.o.timeout = true
vim.o.timeoutlen = 1000

-- Cursor settings and behaviours
vim.o.guicursor = table.concat({
	"n-v:block", -- Normal + Visual = block
	"i:hor20", -- Insert = horizontal underline (20% height)
	"i:hor20-blinkwait600-blinkon700-blinkoff600", -- blinking
	"r-cr:hor20", -- Replace & Command-replace = underline too
	"c-sm:hor20", -- Command-line & Select-mode = underline
}, ",")

-- ──────────────────────────────────────────────
-- Neovide GUI Configuration (macOS)
-- ──────────────────────────────────────────────
if vim.g.neovide then
	-- Font and UI scaling
	vim.o.guifont = "FiraCode Nerd Font Mono:h14"
	vim.g.neovide_scale_factor = 1.0

	-- Cursor animations
	vim.g.neovide_cursor_animation_length = 0.05
	vim.g.neovide_cursor_trail_size = 0.3
	vim.g.neovide_cursor_antialiasing = true
	vim.g.neovide_cursor_vfx_mode = "railgun"

	-- Transparency and blur
	vim.g.neovide_opacity = 0.96
	vim.g.neovide_window_blurred = true

	-- macOS-style keymaps
	vim.g.neovide_input_macos_option_key_is_meta = "only_left"

	-- Remember size between launches
	vim.g.neovide_remember_window_size = true

	-- Custom keybindings
	vim.keymap.set("n", "<D-s>", ":w<CR>")
	vim.keymap.set("v", "<D-c>", '"+y')
	vim.keymap.set("n", "<D-v>", '"+P')
	vim.keymap.set("i", "<D-v>", '<ESC>"+Pli')
end

-- Dynamic Neovide window title
if vim.g.neovide then
	vim.o.title = true

	local function update_title()
		local cwd = vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
		local file = vim.fn.expand("%:t")

		if file ~= "" then
			local mode = vim.api.nvim_get_mode().mode
			vim.o.titlestring = string.format("nvim — %s/%s [%s]", cwd, file, mode)
		else
			vim.o.titlestring = "nvim — " .. cwd
		end
	end

	update_title()

	vim.api.nvim_create_autocmd({ "BufEnter", "DirChanged" }, {
		callback = update_title,
	})
end

-- UI/UX tweaks
vim.o.cmdheight = 1
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.scrolloff = 4
vim.opt.sidescrolloff = 8
vim.opt.clipboard = "unnamedplus"
vim.opt.termguicolors = true

vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true
vim.opt.smartindent = true

vim.opt.splitbelow = true
vim.opt.splitright = true

-- Mouse + focus/hover behaviour
vim.opt.mouse = "a"
vim.opt.mousemodel = "popup"
vim.opt.mousehide = true
vim.opt.mousemoveevent = true
vim.opt.mousefocus = true
vim.opt.mousescroll = "ver:3,hor:6"

-- Lazy.nvim bootstrap
local lazypath = vim.fn.stdpath("config") .. "/lazy/lazy.nvim"
local uv = vim.uv or vim.loop

if not uv.fs_stat(lazypath) then
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

require("lazy").setup("plugins", {
	lockfile = vim.fn.stdpath("config") .. "/lazy-lock.json",
	performance = {
		cache = { enabled = true },
	},
	rocks = {
		enabled = false,
		hererocks = false,
	},
})

-- Keymaps: single entrypoint
safe_require("keymaps.init")

-- Initialise Codex mode + commands
safe_require("codex_setup")

-- Theme cycling
pcall(function()
	require("theme_cycle").setup({
		{ scheme = "tokyonight-night", id = "tokyonight" },
		{ scheme = "gruvbox", id = "gruvbox" },
		{ scheme = "catppuccin", id = "catppuccin" },
		{ scheme = "rose-pine", id = "rose-pine" },
		{ scheme = "kanagawa", id = "kanagawa" },
	}, "tokyonight-night")
end)

-- --------------------------------------------------------------------
-- LSP: clangd (Neovim 0.11+ native config; fallback to nvim-lspconfig)
-- --------------------------------------------------------------------

local caps = vim.lsp.protocol.make_client_capabilities()
local ok_cmp, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
if ok_cmp then
	caps = cmp_nvim_lsp.default_capabilities(caps)
end

local function clangd_root(bufnr, on_dir)
	local fname = vim.api.nvim_buf_get_name(bufnr)

	if not fname or fname == "" then
		on_dir(nil)
		return
	end

	local projects = "/Users/shane/Documents/Coding/c-projects"
	if fname:sub(1, #projects) == projects then
		on_dir(projects)
		return
	end

	local root = vim.fs.root(fname, {
		"compile_commands.json",
		"compile_flags.txt",
		"CMakeLists.txt",
		".git",
	})

	on_dir(root or vim.fs.dirname(fname))
end

local clangd_cfg = {
	cmd = { "clangd" },
	capabilities = caps,
	root_dir = clangd_root,
	filetypes = { "c", "cpp", "objc", "objcpp" },
}

if vim.lsp.config and vim.lsp.enable then
	vim.lsp.config.clangd = clangd_cfg
	vim.lsp.enable("clangd")
else
	local ok_lspconfig, lspconfig = pcall(require, "lspconfig")
	if ok_lspconfig then
		lspconfig.clangd.setup({
			cmd = { "clangd" },
			capabilities = caps,
			root_dir = function(fname)
				local projects = "/Users/shane/Documents/Coding/c-projects"
				if fname:sub(1, #projects) == projects then
					return projects
				end

				local root = vim.fs.root(fname, {
					"compile_commands.json",
					"compile_flags.txt",
					"CMakeLists.txt",
					".git",
				})

				return root or vim.fs.dirname(fname)
			end,
			filetypes = { "c", "cpp", "objc", "objcpp" },
		})
	end
end

-- Soft wrap for coding
vim.opt.wrap = true
vim.opt.linebreak = true
vim.opt.list = true
vim.opt.listchars = {
	eol = "↴",
	tab = "→ ",
	trail = "·",
	extends = "⟩",
	precedes = "⟨",
	nbsp = "␣",
}

vim.opt.cursorline = true
vim.opt.showmode = false
vim.opt.signcolumn = "yes"

-- Search tweaks
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- Highlight curly quotes in Lua config automatically
local group = vim.api.nvim_create_augroup("HighlightCurlyQuotes", { clear = true })

vim.api.nvim_create_autocmd("BufReadPost", {
	group = group,
	pattern = "*.lua",
	callback = function(args)
		require("diag.curly_quotes").attach(args.buf)
	end,
})

vim.api.nvim_create_user_command("FixCurlyQuotes", function()
	local subs = {
		["“"] = '"',
		["”"] = '"',
		["‘"] = "'",
		["’"] = "'",
	}

	for bad, good in pairs(subs) do
		vim.cmd("%s/" .. bad .. "/" .. good .. "/g")
	end

	print("Curly quotes cleaned ✓")
end, {})