-- ~/.config/nvim/lua/keymaps/run.lua
local run = require("run")

vim.keymap.set("n", "<leader>rb", run.build_and_run_current_c_cpp, {
	desc = "Run: Build & run current C/C++ file",
})

vim.keymap.set("n", "<leader>rd", run.build_and_debug_current_c_cpp, {
	desc = "Run: Build & debug current C/C++ file",
})

vim.keymap.set("n", "<leader>rm", run.build_project_with_make, {
	desc = "Run: make in project root",
})
