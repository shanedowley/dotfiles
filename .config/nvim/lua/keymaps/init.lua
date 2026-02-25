-- ~/.config/nvim/lua/keymaps/init.lua
require("keymaps.general")
require("keymaps.lsp")
require("keymaps.dap")
require("keymaps.run")
require("keymaps.terminal")
require("keymaps.git")
require("keymaps.rust")

-- -------------------------------------------------------------------
-- Codex keymaps (robust visual capture)
-- -------------------------------------------------------------------

local explain_prompt = "Explain what this code does step-by-step as C or C++. "
	.. "Call out any undefined behaviour, lifetime issues, and common mistakes. "
	.. "Do NOT rewrite it unless I ask."

-- Remove any competing mappings (Lazy/which-key/plugin)
pcall(vim.keymap.del, "n", "<leader>cE")
pcall(vim.keymap.del, "x", "<leader>cE")
pcall(vim.keymap.del, "s", "<leader>cE")
pcall(vim.keymap.del, "x", "<leader>cs")
pcall(vim.keymap.del, "s", "<leader>cs")

-- Helper: capture visual selection using live marks (v and .), no :normal, no registers
local function get_visual_selection_text()
	local buf = 0

	-- What kind of Visual mode are we in right now?
	-- 'v' = charwise, 'V' = linewise, '\22' = blockwise
	local vmode = vim.fn.visualmode()

	-- In Visual mode:
	--   "v" is the anchor where Visual started
	--   "." is the current cursor
	local vpos = vim.fn.getpos("v")
	local cpos = vim.fn.getpos(".")

	local srow, scol = vpos[2], vpos[3]
	local erow, ecol = cpos[2], cpos[3]

	-- normalize start/end
	if (srow > erow) or (srow == erow and scol > ecol) then
		srow, erow = erow, srow
		scol, ecol = ecol, scol
	end

	-- LINEWISE visual: ignore columns, take whole lines
	if vmode == "V" then
		local lines = vim.api.nvim_buf_get_lines(buf, srow - 1, erow, false) -- end is exclusive, erow is inclusive => OK
		return table.concat(lines, "\n")
	end

	-- CHARWISE visual: use exact cols
	local srow0 = srow - 1
	local erow0 = erow - 1
	local scol0 = scol - 1

	-- end_col for nvim_buf_get_text is EXCLUSIVE (0-based)
	-- ecol is 1-based inclusive => ecol works as exclusive in 0-based
	local ecol0 = ecol

	local lines = vim.api.nvim_buf_get_text(buf, srow0, scol0, erow0, ecol0, {})
	return table.concat(lines, "\n")
end

-- Visual: Explain selection
vim.keymap.set("x", "<leader>cE", function()
	local text = get_visual_selection_text()

	-- Defer everything that mutates editor state until after expr eval completes
	vim.schedule(function()
		local esc = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
		vim.api.nvim_feedkeys(esc, "n", false)

		vim.notify(("PROBE len=%d text=%q"):format(#text, text), vim.log.levels.WARN)

		-- keep this line for now
		require("codex_cli").explain_text(text)
	end)

	return "<Ignore>" -- swallow the keys so nothing leaks into the buffer
end, {
	desc = "Codex: Explain selection",
	silent = true,
	noremap = true,
	nowait = true,
	expr = true,
})

-- Normal: Explain (uses scratchpad prompt against current buffer)
vim.keymap.set("n", "<leader>cE", function()
	require("codex_cli").scratchpad_prompt(explain_prompt)
end, { desc = "Codex: Explain", silent = true, noremap = true })

-- Visual: Scratchpad prompt (run on current buffer text, but invoked from Visual)
vim.keymap.set("x", "<leader>cs", function()
	vim.schedule(function()
		-- exit Visual mode safely (avoid :normal!)
		local esc = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
		vim.api.nvim_feedkeys(esc, "n", false)

		require("codex_cli").scratchpad_prompt()
	end)

	return "<Ignore>"
end, {
	desc = "Codex: Scratchpad prompt (Visual)",
	silent = true,
	noremap = true,
	nowait = true,
	expr = true,
})
