-- ~/.config/nvim/lua/keymaps/general.lua
local map = vim.keymap.set
local opts = { noremap = true, silent = true }

-- Example general maps (edit to match what your monolith currently has)
map("n", "<leader>w", "<cmd>w<CR>", vim.tbl_extend("force", opts, { desc = "Save" }))
map("n", "<leader>qq", "<cmd>qa<CR>", vim.tbl_extend("force", opts, { desc = "Quit all" }))

-- Window navigation (example)
map("n", "<leader>wh", "<C-w>h", vim.tbl_extend("force", opts, { desc = "Window left" }))
map("n", "<leader>wj", "<C-w>j", vim.tbl_extend("force", opts, { desc = "Window down" }))
map("n", "<leader>wk", "<C-w>k", vim.tbl_extend("force", opts, { desc = "Window up" }))
map("n", "<leader>wl", "<C-w>l", vim.tbl_extend("force", opts, { desc = "Window right" }))
