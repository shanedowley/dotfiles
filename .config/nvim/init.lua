-- Set <Leader> key
vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.keymap.set("x", "<leader>pm", function()
	vim.notify("probe: mode=" .. vim.fn.mode(), vim.log.levels.WARN)
end, { desc = "probe mode in visual" })

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

-- Standard macOS XDG layout (no sandbox overrides)
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

-- Ensure timeouts are sane
vim.o.timeout = true
vim.o.timeoutlen = 1000

-- Curor settings and behaviours
vim.o.guicursor = table.concat({
	"n-v:block", -- Normal + Visual = block
	"i:hor20", -- Insert = horizontal underline (20% height)
	"i:hor20-blinkwait600-blinkon700-blinkoff600", -- blinking
	"r-cr:hor20", -- Replace & Command-replace = underline too
	"c-sm:hor20", -- Command-line & Select-mode = underline
}, ",")

-- ──────────────────────────────────────────────
-- 🪟 Neovide GUI Configuration (macOS)
-- ──────────────────────────────────────────────
if vim.g.neovide then
	-- Font and UI scaling
	vim.o.guifont = "FiraCode Nerd Font Mono:h14" -- use any installed font
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
			local mode = vim.api.nvim_get_mode().mode
			title = string.format("nvim — %s/%s [%s]", cwd, file, mode)
			vim.o.titlestring = title
		else
			vim.o.titlestring = "nvim — " .. cwd
		end
	end
	-- run once at startup
	update_title()

	-- update on file or directory changes
	vim.api.nvim_create_autocmd({ "BufEnter", "DirChanged" }, {
		callback = update_title,
	})
end

-- UI/UX tweaks
vim.o.cmdheight = 1
vim.opt.number = true
vim.opt.scrolloff = 4
vim.opt.relativenumber = true
vim.opt.clipboard = "unnamedplus"
vim.opt.termguicolors = true
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true
vim.opt.smartindent = true
vim.opt.splitbelow = true
vim.opt.splitright = true

-- Mouse + focus/hover behavior
vim.opt.mouse = "a" -- enable mouse everywhere
vim.opt.mousemodel = "popup" -- popup menu for clicks
vim.opt.mousehide = true -- hide mouse cursor when typing
vim.opt.mousemoveevent = true -- send mouse-move events to Neovim
vim.opt.mousefocus = true -- focus the split under the mouse
vim.opt.mousescroll = "ver:3,hor:6"

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
		cache = { enabled = true }, -- good default; speeds startup
	},
	rocks = {
		enabled = false,
		hererocks = false,
	},
})

-- Keymaps: single entrypoint
safe_require("keymaps.init")

-- Call themes
pcall(function()
	require("theme_cycle").setup({
		{ scheme = "tokyonight-night", id = "tokyonight" },
		{ scheme = "gruvbox", id = "gruvbox" },
		{ scheme = "catppuccin", id = "catppuccin" },
		{ scheme = "rose-pine", id = "rose-pine" },
		{ scheme = "kanagawa", id = "kanagawa" },
	}, "tokyonight-night")
end)

-- -----------------------------------------------------------------
-- LSP: clangd (Neovim 0.11+ native config; fallback to nvim-lspconfig)
-- -----------------------------------------------------------------

local caps = vim.lsp.protocol.make_client_capabilities()
local ok_cmp, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
if ok_cmp then
	caps = cmp_nvim_lsp.default_capabilities(caps)
end

local function clangd_root(fname)
	local projects = "/Users/shane/Documents/Coding/c-projects"
	if fname:sub(1, #projects) == projects then
		return projects
	end
	local root = vim.fs.root(fname, { "compile_commands.json", "compile_flags.txt", "CMakeLists.txt", ".git" })
	return root or vim.fs.dirname(fname)
end

local clangd_cfg = {
	capabilities = caps,
	root_dir = clangd_root,
	filetypes = { "c", "cpp", "objc", "objcpp" },
}

-- Neovim 0.11+ way
if vim.lsp.config and vim.lsp.enable then
	vim.lsp.config.clangd = clangd_cfg
	vim.lsp.enable("clangd")
else
	-- Fallback for older setups
	local ok_lspconfig, lspconfig = pcall(require, "lspconfig")
	if ok_lspconfig then
		lspconfig.clangd.setup(clangd_cfg)
	end
end

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

-- Sign column (for git/lsp markers)
vim.opt.signcolumn = "yes" -- always show, avoids text shifting

-- Search tweaks
vim.opt.ignorecase = true -- ignore case when searching...
vim.opt.smartcase = true -- ...unless search has capitals

-- Scrolling comfort
vim.opt.sidescrolloff = 8 -- same for left/right scrolling

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

---------------------------------------------------------------------------
-- Auto-format on save for Rust, C/C++, JS/TS, Assembly (LSP-based)
---------------------------------------------------------------------------

-- One augroup to keep things tidy
local fmt_group = vim.api.nvim_create_augroup("AutoFormatOnSave", { clear = true })

-- Helper to build LSP format callbacks with an optional client filter
local function lsp_format_cb(filter_fn)
	return function()
		vim.lsp.buf.format({
			timeout_ms = 2000,
			filter = filter_fn,
		})
	end
end

-- Rust: use rust-analyzer (rustfmt under the hood)
vim.api.nvim_create_autocmd("BufWritePre", {
	group = fmt_group,
	pattern = "*.rs",
	callback = lsp_format_cb(function(client)
		return client.name == "rust_analyzer"
	end),
})

-- C / C++: use clangd
vim.api.nvim_create_autocmd("BufWritePre", {
	group = fmt_group,
	pattern = { "*.c", "*.h", "*.cpp", "*.cc", "*.hpp", "*.hh" },
	callback = lsp_format_cb(function(client)
		return client.name == "clangd"
	end),
})

-- JavaScript / TypeScript: use tsserver or vtsls if present
vim.api.nvim_create_autocmd("BufWritePre", {
	group = fmt_group,
	pattern = { "*.js", "*.jsx", "*.ts", "*.tsx" },
	callback = lsp_format_cb(function(client)
		return client.name == "tsserver" or client.name == "vtsls"
	end),
})

-- Assembly: try any attached LSP/formatter (no filter)
-- (safe no-op if nothing supports formatting)
vim.api.nvim_create_autocmd("BufWritePre", {
	group = fmt_group,
	pattern = { "*.s", "*.S", "*.asm" },
	callback = function()
		vim.lsp.buf.format({ timeout_ms = 2000 })
	end,
})
