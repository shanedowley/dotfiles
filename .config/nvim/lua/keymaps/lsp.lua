-- ~/.config/nvim/lua/keymaps/lsp.lua
local map = vim.keymap.set

-- LSP core
map("n", "<leader>ld", vim.lsp.buf.definition, { desc = "LSP: Definition" })
map("n", "<leader>lD", vim.lsp.buf.declaration, { desc = "LSP: Declaration" })
map("n", "<leader>lr", vim.lsp.buf.rename, { desc = "LSP: Rename" })
map("n", "<leader>la", vim.lsp.buf.code_action, { desc = "LSP: Code action" })
map("n", "<leader>lh", vim.lsp.buf.hover, { desc = "LSP: Hover" })
map("n", "<leader>lf", function()
	vim.lsp.buf.format({ async = true })
end, { desc = "LSP: Format" })

-- Diagnostics
map("n", "<leader>le", vim.diagnostic.open_float, { desc = "Diag: Line diagnostics" })
map("n", "<leader>l[", vim.diagnostic.goto_prev, { desc = "Diag: Prev" })
map("n", "<leader>l]", vim.diagnostic.goto_next, { desc = "Diag: Next" })
