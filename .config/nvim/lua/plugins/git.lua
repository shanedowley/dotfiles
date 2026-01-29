-- Consolidated Git tooling (gitsigns + lazygit + fugitive) without duplicate specs.
local function open_lazygit()
	pcall(vim.cmd.write)

	local cwd = vim.fn.getcwd()
	local root = cwd
	local ok, out = pcall(vim.fn.systemlist, { "git", "-C", cwd, "rev-parse", "--show-toplevel" })
	if ok and out and out[1] and out[1] ~= "" then
		root = out[1]
	end

	local cmd = "cd " .. vim.fn.shellescape(root) .. " && lazygit"
	local applescript = ([[osascript -e '
    tell application "iTerm"
      tell current window
        create tab with default profile
        tell current session
          write text "%s"
        end tell
      end tell
    end tell'
  ]]):format(cmd:gsub('"', '\\"'))

	os.execute(applescript)
end

return {
	{
		"lewis6991/gitsigns.nvim",
		event = { "BufReadPre", "BufNewFile" },
		opts = {
			signs = {
				add = { text = "▎" },
				change = { text = "▎" },
				delete = { text = "" },
				topdelete = { text = "" },
				changedelete = { text = "▎" },
				untracked = { text = "▎" },
			},
			signcolumn = true,
			numhl = false,
			linehl = false,
			word_diff = false,
			current_line_blame = true,
			current_line_blame_opts = { delay = 400, ignore_whitespace = true },
			attach_to_untracked = true,
		},
		config = function(_, opts)
			local gitsigns = require("gitsigns")

			opts.on_attach = function(bufnr)
				local gs = package.loaded.gitsigns
				local map = function(mode, lhs, rhs, desc, extra)
					local merged = { buffer = bufnr, desc = desc, silent = true }
					if extra then
						for k, v in pairs(extra) do
							merged[k] = v
						end
					end
					vim.keymap.set(mode, lhs, rhs, merged)
				end

				-- Hunk navigation (preserve default behaviour inside :diff)
				map("n", "]c", function()
					if vim.wo.diff then
						return "]c"
					end
					vim.schedule(gs.next_hunk)
					return "<Ignore>"
				end, "Git: next hunk", { expr = true })

				map("n", "[c", function()
					if vim.wo.diff then
						return "[c"
					end
					vim.schedule(gs.prev_hunk)
					return "<Ignore>"
				end, "Git: prev hunk", { expr = true })

				-- Which-Key `<leader>g*` expectations
				map("n", "<leader>gs", gs.stage_hunk, "Git: stage hunk")
				map("n", "<leader>gr", gs.reset_hunk, "Git: reset hunk")
				map("n", "<leader>gS", gs.stage_buffer, "Git: stage buffer")
				map("n", "<leader>gR", gs.reset_buffer, "Git: reset buffer")
				map("n", "<leader>gp", gs.preview_hunk, "Git: preview hunk")
				map("n", "<leader>gb", gs.toggle_current_line_blame, "Git: toggle blame (line)")
				map("n", "<leader>gd", gs.diffthis, "Git: diff against index")
				map("n", "<leader>gD", function()
					gs.diffthis("~")
				end, "Git: diff against HEAD~1")
				map("n", "<leader>gn", gs.next_hunk, "Git: next hunk")
				map("n", "<leader>gN", gs.prev_hunk, "Git: previous hunk")
				map("n", "<leader>gu", gs.undo_stage_hunk, "Git: undo stage hunk")

				-- Visual selections and misc helpers stay under the git prefix
				map("v", "<leader>gs", function()
					local start = vim.fn.line(".")
					local finish = vim.fn.line("v")
					gs.stage_hunk({ start, finish })
				end, "Git: stage selection")
				map("v", "<leader>gr", function()
					local start = vim.fn.line(".")
					local finish = vim.fn.line("v")
					gs.reset_hunk({ start, finish })
				end, "Git: reset selection")
				map("n", "<leader>tb", gs.toggle_current_line_blame, "Git: toggle blame (line)")
			end

			gitsigns.setup(opts)
		end,
	},

	-- Lazygit launcher (iTerm2 tab)
	{
		"kdheepak/lazygit.nvim",
		cmd = { "LazyGit", "LazyGitCurrentFile", "LazyGitFilter", "LazyGitFilterCurrentFile" },
		keys = {},
		dependencies = { "nvim-lua/plenary.nvim" },
		init = function()
			local function apply_mapping()
				pcall(vim.keymap.del, "n", "<leader>gl")
				vim.keymap.set("n", "<leader>gl", open_lazygit, {
					desc = "Git: Lazygit (iTerm2 tab)",
					silent = true,
				})
			end

			vim.api.nvim_create_user_command("LazyGitIterm", open_lazygit, { desc = "Open Lazygit in iTerm2 tab" })

			apply_mapping()

			vim.api.nvim_create_autocmd("User", {
				pattern = "VeryLazy",
				callback = apply_mapping,
			})
		end,
		config = function()
			-- ensure mapping still points to iTerm launcher after plugin loads
			vim.schedule(function()
				vim.keymap.set("n", "<leader>gl", open_lazygit, {
					desc = "Git: Lazygit (iTerm2 tab)",
					silent = true,
				})
			end)
		end,
	},

	-- Fugitive
	{
		"tpope/vim-fugitive",
		cmd = { "G", "Git", "Gdiffsplit", "Gblame" },
		keys = {
			{ "<leader>gg", "<cmd>Git<CR>", desc = "Git: status (Fugitive)" },
			{ "<leader>gB", "<cmd>Gblame<CR>", desc = "Git: blame (split)" },
		},
	},
}
