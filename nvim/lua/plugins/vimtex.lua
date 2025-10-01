return {
	"lervag/vimtex",
	ft = { "tex" },
	init = function()
		-- must be set before VimTeX loads
		vim.g.vimtex_compiler_method = "latexmk"
		vim.g.vimtex_view_method = "general"
		vim.g.vimtex_view_general_viewer = "open -a Preview"
		vim.g.vimtex_view_general_options = '"%p"' -- quote the expanded path
	end,
	config = function()
		-- your existing vimtex keymaps
		vim.keymap.set("n", "<leader>lc", "<cmd>VimtexCompile<CR>", { desc = "Compile LaTeX" })
		vim.keymap.set("n", "<leader>lv", "<cmd>VimtexView<CR>", { desc = "View PDF (vimtex)" })

		-- Fallback preview keymap (buffer-local for TeX)
		vim.api.nvim_create_autocmd("FileType", {
			pattern = "tex",
			callback = function(ev)
				vim.keymap.set("n", "<leader>lp", function()
					local pdf = vim.fn.expand("%:p:r") .. ".pdf"
					if vim.fn.filereadable(pdf) == 0 then
						vim.notify("PDF not found: " .. pdf .. " — compile first (<leader>lc).", vim.log.levels.WARN)
						return
					end
					vim.fn.jobstart({ "open", "-a", "Preview", pdf }, { detach = true })
				end, { buffer = ev.buf, desc = "Preview PDF (fallback)" })
			end,
		})
	end,
}
