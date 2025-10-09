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
			group = group,
			nested = true,
			callback = function()
				if #vim.api.nvim_list_wins() == 1 and vim.bo.filetype == "NvimTree" then
					vim.cmd("quit!")
				end
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
			sync_root_with_cwd = true,
		})
	end,
}
