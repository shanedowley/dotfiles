-- Consolidated nvim-tree spec (merges previous duplicate configs)
return {
	"nvim-tree/nvim-tree.lua",
	version = "*",
	lazy = false,
	cmd = { "NvimTreeToggle", "NvimTreeFocus", "NvimTreeFindFileToggle" },
	dependencies = {
		"nvim-tree/nvim-web-devicons",
	},
	keys = {
		{
			"<leader>e",
			"<cmd>NvimTreeToggle<CR>",
			desc = "File tree: toggle",
		},
		{
			"<leader>.",
			function()
				local ok, api = pcall(require, "nvim-tree.api")
				if ok then
					api.tree.toggle_hidden_filter()
				end
			end,
			desc = "File tree: toggle hidden files",
		},
	},
	init = function()
		local group = vim.api.nvim_create_augroup("NvimTreeAutoSetup", { clear = true })

		vim.api.nvim_create_autocmd("VimEnter", {
			group = group,
			callback = function()
				local ok, api = pcall(require, "nvim-tree.api")
				if not ok then
					return
				end
				api.tree.open()
				if vim.fn.expand("%") ~= "" then
					vim.cmd.wincmd("p")
				end
			end,
		})
		vim.api.nvim_create_autocmd("BufEnter", {
			nested = true,
			callback = function()
				-- Only act if NvimTree is the only window
				if #vim.api.nvim_list_wins() ~= 1 or vim.bo.filetype ~= "NvimTree" then
					return
				end

				-- Check for any modified buffers; if any are modified, do NOT quit
				for _, buf in ipairs(vim.api.nvim_list_bufs()) do
					if vim.api.nvim_buf_is_loaded(buf) and vim.api.nvim_buf_get_option(buf, "modified") then
						return
					end
				end

				-- Safe to quit: no modified buffers
				vim.cmd("quit")
			end,
		})
	end,
	config = function()
		require("nvim-tree").setup({
			view = {
				width = 35,
				side = "left",
				relativenumber = true,
			},
			renderer = {
				group_empty = true,
				highlight_git = false,
				icons = {
					show = {
						git = false,
					},
				},
			},
			filters = {
				dotfiles = false,
				custom = { "node_modules", ".git" },
			},
			git = {
				enable = false,
			},
			update_focused_file = {
				enable = true,
				update_root = true,
			},
			filesystem_watchers = {
				enable = false, -- disable fs_event watchers
			},
			sync_root_with_cwd = true,
		})
	end,
}
