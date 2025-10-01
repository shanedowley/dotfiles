-- ~/.config/nvim/lua/plugins/autopairs.lua
return {
	-- Autopairs (auto-close brackets, parens, etc.)
	{
		"windwp/nvim-autopairs",
		event = "InsertEnter",
		config = function()
			local ok_npairs, npairs = pcall(require, "nvim-autopairs")
			if not ok_npairs then
				return
			end

			-- Configure autopairs
			npairs.setup({
				check_ts = true, -- treesitter integration
				ts_config = {
					lua = { "string" },
					javascript = { "template_string" },
					java = false,
				},
				disable_filetype = { "TelescopePrompt", "vim" },

				-- Prep fast_wrap for NVIM 0.11+: do NOT let autopairs inject its own mapping.
				-- We'll provide our own expr mappings below.
				fast_wrap = {
					map = nil, -- important: nil (not ""), avoids "Invalid (empty) LHS" and prevents default <M-e>/<M-w>
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

			-- nvim-cmp integration
			local ok_cmp, cmp = pcall(require, "cmp")
			if ok_cmp then
				local cmp_autopairs = require("nvim-autopairs.completion.cmp")
				cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done())
			end

			-- Helper to map fast_wrap as an expr mapping (returns keys)
			local function map_fastwrap(lhs, desc)
				vim.keymap.set("i", lhs, function()
					local ok_fw, fw = pcall(require, "nvim-autopairs.fastwrap")
					if not ok_fw then
						return ""
					end
					return fw.show() -- when fixed upstream, this will display hint letters
				end, { expr = true, noremap = true, silent = true, desc = desc or "Autopairs fast wrap" })
			end

			-- Preferred key + reliable fallback
			map_fastwrap("<M-w>", "Autopairs fast wrap (Alt/Option+w)")
			map_fastwrap("<C-f>", "Autopairs fast wrap (Ctrl+f fallback)")

			-- Manual test command: :FastWrapShow
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

	-- Surround support (like vim-surround)
	{
		"kylechui/nvim-surround",
		version = "*",
		lazy = false, -- load immediately
		config = function()
			require("nvim-surround").setup({})
		end,
	},

	-- Which-key helper for custom surround shortcuts
	{
		"folke/which-key.nvim",
		opts = {
			defaults = {
				["<leader>m"] = { name = "+surround" },
			},
		},
		config = function(_, opts)
			local wk = require("which-key")
			wk.setup(opts)

			wk.add({
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
		end,
	},
}

--[[
Cheatsheet:

Autopairs:
  • Insert mode: pairs auto-close. Backspace/CR behavior integrated with Treesitter.
  • Fast Wrap (when upstream fix lands for NVIM 0.11+):
      - Primary: Option/Alt + w
      - Fallback: Ctrl + f
      Steps: type text → cursor at target → press key → hint letters appear → press a hint → type the pair (() [] {} "" '')
  • Manual test any time: :FastWrapShow

Surround (nvim-surround):
  ysiw"   → surround inner word with "quotes"
  ysiw'   → surround inner word with 'single quotes'
  ysiw)   → surround inner word with ( )
  ysiw}   → surround inner word with { }
  yss"    → surround entire line with "quotes"
  cs"'    → change " to '
  ds"     → delete " surround

Leader Shortcuts:
  <leader>mq  → surround word with "quotes"
  <leader>mb  → surround word with {braces}
  <leader>mp  → surround word with (parens)
--]]
