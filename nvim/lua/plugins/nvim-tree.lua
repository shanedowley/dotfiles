return {
	"nvim-tree/nvim-tree.lua",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	version = "*",
	config = function()
		require("nvim-tree").setup({
			view = {
				width = 35,
				relativenumber = true,
				side = "left",
			},
			renderer = {
				group_empty = true,
				highlight_git = false, -- don't highlight filenames by git status
				icons = {
					show = {
						git = false, -- don't show git icons
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
				enable = true, -- update tree when changing buffers
				update_root = true, -- change root dir to current file’s dir
			},
			sync_root_with_cwd = true, -- keep root in sync with Neovim’s cwd
		})

		-- Toggle file explorer
		vim.keymap.set("n", "<leader>e", "<cmd>NvimTreeToggle<CR>", { desc = "Toggle file explorer" })

		-- Toggle hidden files
		vim.keymap.set("n", "<leader>.", function()
			require("nvim-tree.api").tree.toggle_hidden_filter()
		end, { desc = "Toggle hidden files in file explorer" })

		-- Auto-open NvimTree when Neovim starts
		vim.api.nvim_create_autocmd("VimEnter", {
			callback = function()
				require("nvim-tree.api").tree.open()
			end,
		})

		-- Auto-close Neovim if NvimTree is the last window
		vim.api.nvim_create_autocmd("BufEnter", {
			nested = true,
			callback = function()
				if #vim.api.nvim_list_wins() == 1 and vim.bo.filetype == "NvimTree" then
					vim.cmd("quit")
				end
			end,
		})
	end,
}
