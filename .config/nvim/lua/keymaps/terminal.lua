-- lua/keymaps/terminal.lua

local opts = { noremap = true, silent = true }

-- Exit terminal mode
vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]], opts)

-- Navigate splits from terminal mode
vim.keymap.set("t", "<C-h>", [[<C-\><C-n><C-w>h]], opts)
vim.keymap.set("t", "<C-j>", [[<C-\><C-n><C-w>j]], opts)
vim.keymap.set("t", "<C-k>", [[<C-\><C-n><C-w>k]], opts)
vim.keymap.set("t", "<C-l>", [[<C-\><C-n><C-w>l]], opts)
