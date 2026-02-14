-- ~/.config/nvim/lua/keymaps/git.lua
local map = vim.keymap.set

map("n", "<leader>gg", "<cmd>Git<CR>", { desc = "Git: Status (Fugitive)" })

map("n", "<leader>gb", function()
	local ok, gs = pcall(require, "gitsigns")
	if ok then
		gs.blame_line()
	end
end, { desc = "Git: Blame line" })

map("n", "<leader>gd", function()
	local ok, gs = pcall(require, "gitsigns")
	if ok then
		gs.diffthis()
	end
end, { desc = "Git: Diff this" })
