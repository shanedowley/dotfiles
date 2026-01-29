-- Consolidated editing helpers: nvim-autopairs + nvim-surround + optional which-key labels.
return {
	{
		"windwp/nvim-autopairs",
		event = "InsertEnter",
		config = function()
			local ok_npairs, npairs = pcall(require, "nvim-autopairs")
			if not ok_npairs then
				return
			end

			npairs.setup({
				check_ts = true,
				ts_config = {
					lua = { "string" },
					javascript = { "template_string" },
					java = false,
				},
				disable_filetype = { "TelescopePrompt", "vim" },
				fast_wrap = {
					map = nil,
					chars = { "{", "[", "(", '"', "'" },
					pattern = string.gsub([[ [%'%"%)%>%]%)%}%,] ]], "%s+", ""),
					offset = 0,
					end_key = "$",
					keys = "qwertyuiopzxcvbnmasdfghjkl",
					check_comma = true,
					highlight = "PmenuSel",
					highlight_grey = "LineNr",
				},
			})

			local ok_cmp, cmp = pcall(require, "cmp")
			if ok_cmp then
				local cmp_autopairs = require("nvim-autopairs.completion.cmp")
				cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done())
			end

			local function map_fastwrap(lhs, desc)
				vim.keymap.set("i", lhs, function()
					local ok_fw, fw = pcall(require, "nvim-autopairs.fastwrap")
					if not ok_fw then
						return ""
					end
					return fw.show()
				end, { expr = true, noremap = true, silent = true, desc = desc or "Autopairs fast wrap" })
			end

			map_fastwrap("<M-w>", "Autopairs fast wrap (Alt/Option+w)")
			map_fastwrap("<C-f>", "Autopairs fast wrap (Ctrl+f fallback)")

			vim.api.nvim_create_user_command("FastWrapShow", function()
				local ok_fw, fw = pcall(require, "nvim-autopairs.fastwrap")
				if not ok_fw then
					vim.notify("nvim-autopairs.fastwrap not available", vim.log.levels.WARN)
					return
				end
				fw.show()
			end, {})
		end,
	},

	{
		"kylechui/nvim-surround",
		event = "VeryLazy",
		config = function()
			require("nvim-surround").setup({})

			local ok, wk = pcall(require, "which-key")
			if ok then
				wk.add({
					{
						"<leader>m",
						group = "+surround",
					},
					{
						"<leader>mb",
						function()
							vim.cmd("normal ysiw{")
						end,
						desc = "Surround word with {}",
					},
					{
						"<leader>mp",
						function()
							vim.cmd("normal ysiw(")
						end,
						desc = "Surround word with ()",
					},
					{
						"<leader>mq",
						function()
							vim.cmd([[normal ysiw"]])
						end,
						desc = [[Surround word with ""]],
					},
				})
			end
		end,
	},
}
