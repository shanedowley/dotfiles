-- ~/.config/nvim/lua/keymaps/init.lua
require("keymaps.general")
require("keymaps.lsp")
require("keymaps.dap")
require("keymaps.run")
require("keymaps.terminal")
require("keymaps.git")
require("keymaps.rust")

-- Force Codex scratchpad from Visual mode (bypass Lazy expr-maps + any plugin defaults)
pcall(vim.keymap.del, "x", "<leader>cs") -- delete whatever is currently there
pcall(vim.keymap.del, "s", "<leader>cE")

vim.keymap.set("x", "<leader>cs", function()
	vim.api.nvim_echo({ { "VISUAL <leader>cs: using codex_cli scratchpad", "WarningMsg" } }, false, {})

	-- Leave visual mode but keep '< and '> marks
	vim.cmd("normal! <Esc>")

	-- Defer so which-key/Lazy finishes handling keys first
	vim.schedule(function()
		require("codex_cli").scratchpad_prompt()
	end)
end, { desc = "Codex: Scratchpad prompt (Visual)", silent = true })

-- -------------------------------------------------------
-- Codex: Explain (learning mode)
-- -------------------------------------------------------

local explain_prompt = "Explain what this code does step-by-step as C (not C++). "
	.. "Call out undefined behavior, lifetime issues, and common beginner mistakes. "
	.. "Do NOT rewrite it unless I ask."

-- Normal mode
vim.keymap.set("n", "<leader>cE", function()
	require("codex_cli").scratchpad_prompt(explain_prompt)
end, { desc = "Codex: Explain (learning)", silent = true })

-- Visual mode
vim.keymap.set("x", "<leader>cE", function()
	vim.cmd("normal! <Esc>")
	vim.schedule(function()
		require("codex_cli").scratchpad_prompt(explain_prompt)
	end)
end, { desc = "Codex: Explain selection (learning)", silent = true })
