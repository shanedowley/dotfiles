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
--
-- IMPORTANT:
-- Lazy.nvim may (re)install its own <leader>c* trigger mappings late in startup.
-- We therefore delete + set ALL Codex mappings after Lazy finishes, using User VeryLazy.
-- -------------------------------------------------------------------

vim.api.nvim_create_autocmd("User", {
	pattern = "VeryLazy",
	callback = function()
		local explain_prompt = "Explain what this code does step-by-step as C or C++. "
			.. "Call out any undefined behaviour, lifetime issues, and common mistakes. "
			.. "Do NOT rewrite it unless I ask."

		local codex = require("codex_cli")

		-- Remove any competing mappings (Lazy/which-key/plugin) AFTER Lazy sets them
		for _, mode in ipairs({ "n", "x", "v", "s" }) do
			pcall(vim.keymap.del, mode, "<leader>cE")
			pcall(vim.keymap.del, mode, "<leader>cs")
			pcall(vim.keymap.del, mode, "<leader>ca")
			pcall(vim.keymap.del, mode, "<leader>cD")
			pcall(vim.keymap.del, mode, "<leader>cd")
			pcall(vim.keymap.del, mode, "<leader>cw")
			pcall(vim.keymap.del, mode, "<leader>cr")
			pcall(vim.keymap.del, mode, "<leader>co")
			pcall(vim.keymap.del, mode, "<leader>cS")
			pcall(vim.keymap.del, mode, "<leader>cl")
			pcall(vim.keymap.del, mode, "<leader>cF")
		end

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
				local lines = vim.api.nvim_buf_get_lines(buf, srow - 1, erow, false) -- end is exclusive
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

		-- Exit Visual mode safely before prompting/applying
		local function exit_visual_then(fn)
			vim.schedule(function()
				local esc = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
				-- "nx" avoids remaps and behaves nicely from Visual
				vim.api.nvim_feedkeys(esc, "nx", false)

				-- Run on the next tick after Visual truly exits
				vim.schedule(fn)
			end)
		end

		-- Common opts for expr-based Visual mappings
		local function vopts(desc)
			return {
				desc = desc,
				silent = true,
				noremap = true,
				nowait = true,
				expr = true,
			}
		end

		-- -------------------------------------------------------------------
		-- Visual mappings (bind on BOTH x and v so we override Lazy's v-maps)
		-- -------------------------------------------------------------------

		-- Visual: Explain selection
		vim.keymap.set({ "x", "v" }, "<leader>cE", function()
			local text = get_visual_selection_text()
			exit_visual_then(function()
				codex.explain_text(text)
			end)
			return "<Ignore>"
		end, vopts("Codex: Explain selection"))

		-- Visual: Scratchpad prompt
		vim.keymap.set({ "x", "v" }, "<leader>cs", function()
			exit_visual_then(function()
				codex.scratchpad_prompt()
			end)
			return "<Ignore>"
		end, vopts("Codex: Scratchpad prompt (Visual)"))

		-- Visual: Apply inline
		vim.keymap.set({ "x", "v" }, "<leader>ca", function()
			exit_visual_then(function()
				codex.apply_inline()
			end)
			return "<Ignore>"
		end, vopts("Codex: Apply inline (Visual)"))

		-- Visual: Preview diff
		vim.keymap.set({ "x", "v" }, "<leader>cD", function()
			exit_visual_then(function()
				codex.preview_diff()
			end)
			return "<Ignore>"
		end, vopts("Codex: Preview diff (Visual)"))

		-- Visual: Preview diff (alias) - cd as synonym for cD
		vim.keymap.set({ "x", "v" }, "<leader>cd", function()
			exit_visual_then(function()
				codex.preview_diff()
			end)
			return "<Ignore>"
		end, vopts("Codex: Preview diff (Visual)"))

		-- Visual: Replace selection (raw path)
		vim.keymap.set({ "x", "v" }, "<leader>cr", function()
			-- capture selection BEFORE exiting visual
			local text = get_visual_selection_text()

			-- capture the line range using live marks (v and .)
			local vpos = vim.fn.getpos("v")
			local cpos = vim.fn.getpos(".")
			local srow, erow = vpos[2], cpos[2]
			if srow > erow then
				srow, erow = erow, srow
			end

			local ft = vim.bo.filetype or "text"

			exit_visual_then(function()
				codex.replace_range(text, srow, erow, ft)
			end)

			return "<Ignore>"
		end, vopts("Codex: Replace selection (Visual)"))

		-- Visual: Open output scratch (no apply)
		vim.keymap.set({ "x", "v" }, "<leader>co", function()
			exit_visual_then(function()
				codex.open_output_scratch()
			end)
			return "<Ignore>"
		end, vopts("Codex: Open output scratch (Visual)"))

		-- Visual: Write output to file
		vim.keymap.set({ "x", "v" }, "<leader>cw", function()
			local text = get_visual_selection_text()
			exit_visual_then(function()
				codex.save_output_to_file_text(text)
			end)
			return "<Ignore>"
		end, vopts("Codex: Write output to file (Visual)"))

		-- -------------------------------------------------------------------
		-- Normal mappings
		-- -------------------------------------------------------------------

		-- Normal: Explain current line
		vim.keymap.set("n", "<leader>cE", function()
			codex.explain_current_line()
		end, { desc = "Codex: Explain line", silent = true, noremap = true })

		-- Normal: Scratchpad whole file
		vim.keymap.set("n", "<leader>cS", function()
			codex.scratchpad_prompt(explain_prompt)
		end, { desc = "Codex: Scratchpad (File)", silent = true, noremap = true })

		-- Normal: Run current line
		vim.keymap.set("n", "<leader>cl", function()
			codex.run_current_line()
		end, { desc = "Codex: Run current line", silent = true, noremap = true })

		-- Normal: Run entire file
		vim.keymap.set("n", "<leader>cF", function()
			codex.run_entire_file()
		end, { desc = "Codex: Run entire file", silent = true, noremap = true })

		-- Normal: Apply inline (current line)
		vim.keymap.set("n", "<leader>ca", function()
			codex.apply_inline_current_line()
		end, { desc = "Codex: Apply inline (Line)", silent = true, noremap = true })

		-- Normal: Preview diff (current line)
		vim.keymap.set("n", "<leader>cD", function()
			codex.preview_diff_current_line()
		end, { desc = "Codex: Preview diff (Line)", silent = true, noremap = true })
	end,
})
