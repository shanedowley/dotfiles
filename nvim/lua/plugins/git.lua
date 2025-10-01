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
			local gs = require("gitsigns")
			gs.setup(opts)

			-- Hunk navigation
			vim.keymap.set("n", "]c", function()
				gs.nav_hunk("next")
			end, { desc = "Git: next hunk" })
			vim.keymap.set("n", "[c", function()
				gs.nav_hunk("prev")
			end, { desc = "Git: prev hunk" })

			-- Actions
			vim.keymap.set("n", "<leader>gs", gs.stage_hunk, { desc = "Git: stage hunk" })
			vim.keymap.set("n", "<leader>gr", gs.reset_hunk, { desc = "Git: reset hunk" })
			vim.keymap.set("v", "<leader>gs", function()
				gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
			end, { desc = "Git: stage hunk (visual)" })
			vim.keymap.set("v", "<leader>gr", function()
				gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
			end, { desc = "Git: reset hunk (visual)" })
			vim.keymap.set("n", "<leader>gS", gs.stage_buffer, { desc = "Git: stage buffer" })
			vim.keymap.set("n", "<leader>gR", gs.reset_buffer, { desc = "Git: reset buffer" })
			vim.keymap.set("n", "<leader>gp", gs.preview_hunk, { desc = "Git: preview hunk" })
			vim.keymap.set("n", "<leader>gb", gs.toggle_current_line_blame, { desc = "Git: toggle blame" })
			vim.keymap.set("n", "<leader>gd", gs.diffthis, { desc = "Git: diff (index)" })
			vim.keymap.set("n", "<leader>gD", function()
				gs.diffthis("~")
			end, { desc = "Git: diff (HEAD~)" })
		end,
	},

	-- Lazygit in iTerm2 tab
	{
		"kdheepak/lazygit.nvim",
		cmd = { "LazyGit", "LazyGitCurrentFile", "LazyGitFilter", "LazyGitFilterCurrentFile" },
		keys = {
			{
				"<leader>gl",
				function()
					-- Save any edits first
					pcall(vim.cmd.write)

					-- Prefer Git root; fall back to current working dir
					local cwd = vim.fn.getcwd()
					local root = cwd
					local ok, out = pcall(vim.fn.systemlist, { "git", "-C", cwd, "rev-parse", "--show-toplevel" })
					if ok and out and out[1] and out[1] ~= "" then
						root = out[1]
					end

					-- Build a safe shell command for iTerm2
					local cmd = "cd " .. vim.fn.shellescape(root) .. " && lazygit"

					-- Open in a new iTerm2 TAB (change to "split vertically" for a split)
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
				end,
				desc = "Git: Lazygit (iTerm2 tab in repo root)",
			},
		},
		dependencies = { "nvim-lua/plenary.nvim" },
	},

	{
		"lewis6991/gitsigns.nvim",
		event = { "BufReadPre", "BufNewFile" },
		config = function()
			require("gitsigns").setup({
				signs = {
					add = { text = "+" },
					change = { text = "~" },
					delete = { text = "_" },
					topdelete = { text = "‾" },
					changedelete = { text = "~" },
				},
				on_attach = function(bufnr)
					local gs = package.loaded.gitsigns
					local map = function(mode, l, r, desc)
						vim.keymap.set(mode, l, r, { buffer = bufnr, desc = desc })
					end

					-- Navigation
					map("n", "]c", function()
						if vim.wo.diff then
							return "]c"
						end
						vim.schedule(function()
							gs.next_hunk()
						end)
						return "<Ignore>"
					end, "Next Git hunk")

					map("n", "[c", function()
						if vim.wo.diff then
							return "[c"
						end
						vim.schedule(function()
							gs.prev_hunk()
						end)
						return "<Ignore>"
					end, "Prev Git hunk")

					-- Actions
					map("n", "<leader>hs", gs.stage_hunk, "Stage hunk")
					map("n", "<leader>hr", gs.reset_hunk, "Reset hunk")
					map("v", "<leader>hs", function()
						gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
					end, "Stage hunk")
					map("v", "<leader>hr", function()
						gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
					end, "Reset hunk")
					map("n", "<leader>hS", gs.stage_buffer, "Stage buffer")
					map("n", "<leader>hu", gs.undo_stage_hunk, "Undo stage hunk")
					map("n", "<leader>hR", gs.reset_buffer, "Reset buffer")
					map("n", "<leader>hp", gs.preview_hunk, "Preview hunk")
					map("n", "<leader>hb", function()
						gs.blame_line({ full = true })
					end, "Blame line")
					map("n", "<leader>tb", gs.toggle_current_line_blame, "Toggle line blame")
					map("n", "<leader>hd", gs.diffthis, "Diff this")
					map("n", "<leader>hD", function()
						gs.diffthis("~")
					end, "Diff against last commit")
				end,
			})
		end,
	},

	-- Fugitive set up
	{
		"tpope/vim-fugitive",
		cmd = { "G", "Git", "Gdiffsplit", "Gblame" },
		keys = {
			{ "<leader>gg", "<cmd>Git<cr>", desc = "Git: status (Fugitive)" },
			{ "<leader>gB", "<cmd>Gblame<cr>", desc = "Git: blame (split)" },
		},
	},
}
