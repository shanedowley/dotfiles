-- ~/.config/nvim/lua/plugins/treesitter.lua
return {
	"nvim-treesitter/nvim-treesitter",
	build = ":TSUpdate",
	event = { "BufReadPost", "BufNewFile" },
	opts = {
		indent = { enable = true },
		ensure_installed = {
			"lua",
			"c",
			"cpp",
			"vim",
			"json",
			"markdown",
			"markdown_inline",
			"css",
			"javascript",
			"yaml",
			"llvm",
			"html",
			"css",
			"d",
			"c_sharp",
			"angular",
			"asm",
			"bash",
			"liquid",
			"sql",
		}, -- Add more as needed
		auto_install = true,
		highlight = {
			enable = true,
			disable = function(lang, buf)
				if lang == "markdown" or lang == "text" then
					return true
				end

				local max_filesize = 100 * 1024 -- 100 KB
				local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(buf))
				if ok and stats and stats.size > max_filesize then
					return true
				end
			end,
		},
		incremental_selection = {
			enable = true,
			keymaps = {
				init_selection = "<CR>", -- Start selection
				node_incremental = "<CR>", -- Expand to next node
				node_decremental = "<BS>", -- Shrink to previous node
			},
		},
		textobjects = {
			select = {
				enable = true,
				lookahead = true,
				keymaps = {
					["af"] = "@function.outer", -- Around function
					["if"] = "@function.inner", -- Inside function
					["ac"] = "@class.outer", -- Around class
					["ic"] = "@class.inner", -- Inside class
				},
			},
			move = {
				enable = true,
				set_jumps = true,
				goto_next_start = {
					["]m"] = "@function.outer",
				},
				goto_previous_start = {
					["[m"] = "@function.outer",
				},
			},
		},
	},
	dependencies = {
		"nvim-treesitter/nvim-treesitter-textobjects",
	},
	config = function(_, opts)
		require("nvim-treesitter.configs").setup(opts)

		-- 👇 Force Treesitter to treat .z80 files as asm
		vim.treesitter.language.register("asm", "z80")

		-- Optional: also set syntax fallback
		vim.api.nvim_create_autocmd("FileType", {
			pattern = "z80",
			callback = function()
				vim.bo.syntax = "asm"
			end,
		})
	end,
}
