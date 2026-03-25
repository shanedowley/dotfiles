-- Startup sequence for Codex-Neovim implementation
local mode = require("codex_mode")
local codex_cli = require("codex_cli")

local function notify_placement_api()
	return rawget(_G, "CodexNotifyPlacement")
end

vim.api.nvim_create_user_command("CodexMode", function(opts)
	if opts.args == "" then
		vim.notify("Codex mode: " .. mode.current(), vim.log.levels.INFO, { title = "Codex" })
		return
	end
	local ok = mode.set(opts.args)
	if ok then
		vim.notify("Codex mode set: " .. mode.current(), vim.log.levels.INFO, { title = "Codex" })
	else
		vim.notify("Unknown Codex mode: " .. opts.args, vim.log.levels.ERROR, { title = "Codex" })
	end
end, {
	nargs = "?",
	complete = function()
		return mode.names()
	end,
})

vim.api.nvim_create_user_command("CodexModeCycle", function()
	local new = mode.cycle()
	vim.notify("Codex mode: " .. new, vim.log.levels.INFO, { title = "Codex" })
end, {})

vim.api.nvim_create_user_command("CodexModeList", function()
	local names = table.concat(mode.names(), ", ")
	vim.notify("Codex modes: " .. names, vim.log.levels.INFO, { title = "Codex" })
end, {})

vim.api.nvim_create_user_command("CodexNotifyPlacement", function(opts)
	local api = notify_placement_api()
	if not api then
		vim.notify("Codex notify placement API is not available", vim.log.levels.ERROR, { title = "Codex" })
		return
	end

	if opts.args == "" then
		vim.notify("Notify placement: " .. api.get(), vim.log.levels.INFO, { title = "Codex" })
		return
	end

	local ok, result = api.set(opts.args)
	if not ok then
		vim.notify(result, vim.log.levels.ERROR, { title = "Codex" })
		return
	end

	vim.notify("Notify placement set and saved: " .. result, vim.log.levels.INFO, { title = "Codex" })
end, {
	nargs = "?",
	complete = function()
		return { "top_left", "top_right", "center", "bottom_left", "bottom_right" }
	end,
})

vim.api.nvim_create_user_command("CodexNotifyTest", function()
	vim.notify("Codex notify placement test", vim.log.levels.INFO, { title = "Codex" })
end, {})

vim.keymap.set("n", "<leader>cm", "<cmd>CodexModeCycle<cr>", {
	desc = "Codex: Cycle mode",
})

vim.keymap.set("n", "<leader>cM", "<cmd>CodexMode<cr>", {
	desc = "Codex: Show mode",
})

vim.keymap.set("n", "<leader>cmr", function()
	require("codex_mode").set("refactor")
	vim.notify("Codex mode set: refactor", vim.log.levels.INFO, { title = "Codex" })
end, { desc = "Codex: mode refactor" })

vim.keymap.set("n", "<leader>cmm", function()
	local m = require("codex_mode").cycle()
	vim.notify("Codex mode: " .. m, vim.log.levels.INFO, { title = "Codex" })
end, { desc = "Codex: cycle mode" })

