-- ~/.config/nvim/lua/plugins/whichkey.lua
return {
	{
		"folke/which-key.nvim",
		event = "VeryLazy",

		init = function()
			-- Remove a few competing mappings
			pcall(vim.keymap.del, "n", "<leader>B")
			for _, lhs in ipairs({ "<leader>+", "<leader>-", "<leader><", "<leader>>" }) do
				pcall(vim.keymap.del, "n", lhs)
				pcall(vim.keymap.del, "v", lhs)
				pcall(vim.keymap.del, "x", lhs)
			end
		end,

		opts = {
			plugins = {
				marks = true,
				registers = true,
				spelling = { enabled = true, suggestions = 20 },
			},

			preset = {
				operators = false,
				motions = false,
				text_objects = false,
				windows = false,
				nav = true,
				z = true,
				g = true,
			},

			filter = function(m)
				if m and m.prefix and m.prefix ~= "<leader>" then
					return true
				end

				local function norm(k)
					if not k then
						return ""
					end
					local s = type(k) == "table" and table.concat(k, "") or k
					return vim.fn.keytrans(s)
				end

				local k = norm(m and m.keys)
				local label = ((m and (m.desc or m.name)) or ""):lower()

				if k == "<C-w>+" or k == "<C-w>-" or k == "<C-w><" or k == "<C-w>>" then
					return false
				end
				if k == "+" or k == "-" or k == "<" or k == ">" then
					return false
				end

				if
					label:find("shrink pane width", 1, true)
					or label:find("grow pane width", 1, true)
					or label:find("shrink pane height", 1, true)
					or label:find("grow pane height", 1, true)
				then
					return false
				end

				return true
			end,

			win = { border = "rounded", padding = { 1, 2, 1, 2 } },
			layout = { align = "left" },
			delay = 0,
			show_help = false,
			show_keys = true,
			icons = { mappings = false },

			triggers = {
				{ "<leader>", mode = "n" },
				{ "<leader>", mode = "x" },
			},

			spec = {
				----------------------------------------------------------------------
				-- ASM
				----------------------------------------------------------------------
				{ "<leader>a", group = "+asm", mode = "n" },
				{ "<leader>ad", desc = "DAP: Build & Debug ARM64 Assembly", mode = "n" },
				{ "<leader>ar", desc = "DAP: Rerun last debug session", mode = "n" },

				----------------------------------------------------------------------
				-- FILE
				----------------------------------------------------------------------
				{ "<leader>f", group = "+file", mode = "n" },
				{ "<leader>fe", "<cmd>NvimTreeToggle<CR>", desc = "Explorer", mode = "n" },
				{ "<leader>ff", "<cmd>Telescope find_files<CR>", desc = "Find file", mode = "n" },
				{ "<leader>fg", "<cmd>Telescope live_grep<CR>", desc = "Live grep", mode = "n" },
				{ "<leader>fr", "<cmd>Telescope oldfiles<CR>", desc = "Recent files", mode = "n" },
				{ "<leader>fs", "<cmd>w<CR>", desc = "Save file", mode = "n" },
				{ "<leader>fS", "<cmd>wa<CR>", desc = "Save all", mode = "n" },
				{ "<leader>fn", "<cmd>enew<CR>", desc = "New file", mode = "n" },

				----------------------------------------------------------------------
				-- BUFFERS
				----------------------------------------------------------------------
				{ "<leader>b", group = "+buffer", mode = "n" },
				{ "<leader>bb", "<cmd>Telescope buffers<CR>", desc = "List buffers", mode = "n" },
				{ "<leader>bn", "<cmd>bnext<CR>", desc = "Next buffer", mode = "n" },
				{ "<leader>bp", "<cmd>bprevious<CR>", desc = "Prev buffer", mode = "n" },
				{ "<leader>bd", "<cmd>bd<CR>", desc = "Delete buffer", mode = "n" },

				----------------------------------------------------------------------
				-- WINDOWS
				----------------------------------------------------------------------
				{ "<leader>w", group = "+window", mode = "n" },
				{ "<leader>wh", "<C-w>h", desc = "Go left", mode = "n" },
				{ "<leader>wj", "<C-w>j", desc = "Go down", mode = "n" },
				{ "<leader>wk", "<C-w>k", desc = "Go up", mode = "n" },
				{ "<leader>wl", "<C-w>l", desc = "Go right", mode = "n" },
				{ "<leader>wv", "<cmd>vsplit<CR>", desc = "Vertical split", mode = "n" },
				{ "<leader>ws", "<cmd>split<CR>", desc = "Horizontal split", mode = "n" },
				{ "<leader>wq", "<cmd>q<CR>", desc = "Close window", mode = "n" },
				{ "<leader>w=", "<C-w>=", desc = "Equalize sizes", mode = "n" },
				{ "<leader>w+", "<cmd>vertical resize +5<CR>", desc = "Increase width (+5)", mode = "n" },
				{ "<leader>w-", "<cmd>vertical resize -5<CR>", desc = "Decrease width (-5)", mode = "n" },
				{ "<leader>w>", "<cmd>resize +3<CR>", desc = "Increase height (+3)", mode = "n" },
				{ "<leader>w<", "<cmd>resize -3<CR>", desc = "Decrease height (-3)", mode = "n" },

				----------------------------------------------------------------------
				-- GIT
				----------------------------------------------------------------------
				{ "<leader>g", group = "+git", mode = "n" },
				{ "<leader>gb", "<cmd>Gitsigns blame_line<CR>", desc = "Blame line", mode = "n" },
				{ "<leader>gB", "<cmd>Git blame<CR>", desc = "Git: blame (split)", mode = "n" },
				{ "<leader>gd", "<cmd>Gitsigns diffthis<CR>", desc = "Diff file", mode = "n" },
				{ "<leader>gg", "<cmd>Git<CR>", desc = "Git: status (Fugitive)", mode = "n" },
				{ "<leader>gl", "<cmd>LazyGit<CR>", desc = "Git: Lazygit", mode = "n" },
				{ "<leader>gn", "<cmd>Gitsigns next_hunk<CR>", desc = "Next hunk", mode = "n" },
				{ "<leader>gN", "<cmd>Gitsigns prev_hunk<CR>", desc = "Prev hunk", mode = "n" },
				{ "<leader>gr", "<cmd>Gitsigns reset_hunk<CR>", desc = "Reset hunk", mode = "n" },
				{ "<leader>gs", "<cmd>Gitsigns stage_hunk<CR>", desc = "Stage hunk", mode = "n" },
				{
					"<leader>gu",
					function()
						require("gitsigns").undo_stage_hunk()
					end,
					desc = "Undo stage hunk",
					mode = "n",
				},
				{
					"<leader>gp",
					function()
						require("gitsigns").preview_hunk()
					end,
					desc = "Preview hunk",
					mode = "n",
				},
				{ "<leader>g", group = "+git", mode = "x" },
				{ "<leader>d", group = "+debug", mode = "x" },
				{ "<leader>gs", desc = "Git: stage selection", mode = "x" },
				{ "<leader>gr", desc = "Git: reset selection", mode = "x" },
				{ "<leader>de", desc = "DAP: Eval", mode = "x" },

				----------------------------------------------------------------------
				-- UI
				----------------------------------------------------------------------
				{ "<leader>u", group = "+ui", mode = "n" },
				{ "<leader>ut", desc = "Switch color scheme", mode = "n" },

				----------------------------------------------------------------------
				-- CODEX
				----------------------------------------------------------------------
				{ "<leader>c", group = "+codex", mode = { "n", "x" } },

				-- Codex terminal / context (normal only)
				{ "<leader>ct", desc = "Terminal: Toggle/Open", mode = "n" },
				{ "<leader>cT", desc = "Terminal: Focus", mode = "n" },
				{ "<leader>cA", desc = "Terminal: Add file to context", mode = "n" },

				-- Normal mode Codex actions
				{ "<leader>cR", desc = "Refactor current function", mode = "n" },
				{ "<leader>cl", desc = "Run on current line", mode = "n" },
				{ "<leader>cF", desc = "Run on entire file", mode = "n" },
				{ "<leader>cp", desc = "Patch buffer (diff)", mode = "n" },
				{ "<leader>cs", desc = "Scratchpad prompt", mode = "n" },
				{ "<leader>cE", desc = "Explain current line", mode = "n" },
				{ "<leader>ca", desc = "Apply inline (current line)", mode = "n" },
				{ "<leader>cD", desc = "Preview diff (current line)", mode = "n" },

				-- Visual mode Codex actions
				{ "<leader>cE", desc = "Explain selection", mode = "x" },
				{ "<leader>cr", desc = "Replace selection", mode = "x" },
				{ "<leader>co", desc = "Open output scratch", mode = "x" },
				{ "<leader>ca", desc = "Apply inline", mode = "x" },
				{ "<leader>cd", desc = "Preview diff", mode = "x" },
				{ "<leader>cw", desc = "Write output to file", mode = "x" },
				{ "<leader>cs", desc = "Scratchpad prompt", mode = "x" },

				----------------------------------------------------------------------
				-- LSP
				----------------------------------------------------------------------
				{ "<leader>l", group = "+lsp", mode = "n" },
				{
					"<leader>ld",
					function()
						vim.lsp.buf.definition()
					end,
					desc = "Definition",
					mode = "n",
				},
				{
					"<leader>lD",
					function()
						vim.lsp.buf.declaration()
					end,
					desc = "Declaration",
					mode = "n",
				},
				{
					"<leader>lr",
					function()
						vim.lsp.buf.rename()
					end,
					desc = "Rename",
					mode = "n",
				},
				{
					"<leader>la",
					function()
						vim.lsp.buf.code_action()
					end,
					desc = "Code action",
					mode = "n",
				},
				{
					"<leader>lh",
					function()
						vim.lsp.buf.hover()
					end,
					desc = "Hover docs",
					mode = "n",
				},
				{
					"<leader>li",
					function()
						vim.lsp.buf.implementation()
					end,
					desc = "Implementation",
					mode = "n",
				},
				{
					"<leader>lt",
					function()
						vim.lsp.buf.type_definition()
					end,
					desc = "Type def",
					mode = "n",
				},
				{
					"<leader>lf",
					function()
						vim.lsp.buf.format({ async = true })
					end,
					desc = "Format",
					mode = "n",
				},
				{ "<leader>ls", "<cmd>Telescope lsp_document_symbols<CR>", desc = "Document symbols", mode = "n" },
				{
					"<leader>lS",
					"<cmd>Telescope lsp_dynamic_workspace_symbols<CR>",
					desc = "Workspace symbols",
					mode = "n",
				},
				{
					"<leader>le",
					function()
						vim.diagnostic.open_float()
					end,
					desc = "Line diagnostics",
					mode = "n",
				},
				{
					"<leader>l]",
					function()
						vim.diagnostic.goto_next()
					end,
					desc = "Next diagnostic",
					mode = "n",
				},
				{
					"<leader>l[",
					function()
						vim.diagnostic.goto_prev()
					end,
					desc = "Prev diagnostic",
					mode = "n",
				},

				----------------------------------------------------------------------
				-- DEBUG
				----------------------------------------------------------------------
				{ "<leader>d", group = "+debug", mode = "n" },

				----------------------------------------------------------------------
				-- TEST
				----------------------------------------------------------------------
				{ "<leader>t", group = "+test", mode = "n" },
				{
					"<leader>tn",
					function()
						require("neotest").run.run()
					end,
					desc = "Run nearest",
					cond = function()
						return package.loaded["neotest"]
					end,
					mode = "n",
				},
				{
					"<leader>tf",
					function()
						require("neotest").run.run(vim.fn.expand("%"))
					end,
					desc = "Run file",
					cond = function()
						return package.loaded["neotest"]
					end,
					mode = "n",
				},
				{
					"<leader>to",
					function()
						require("neotest").output.open({ enter = true })
					end,
					desc = "Open output",
					cond = function()
						return package.loaded["neotest"]
					end,
					mode = "n",
				},
				{
					"<leader>ts",
					function()
						require("neotest").summary.toggle()
					end,
					desc = "Toggle summary",
					cond = function()
						return package.loaded["neotest"]
					end,
					mode = "n",
				},

				----------------------------------------------------------------------
				-- SESSIONS
				----------------------------------------------------------------------
				{ "<leader>q", group = "+sessions", mode = "n" },
				{
					"<leader>qs",
					function()
						if package.loaded["persisted"] then
							require("persisted").save()
						elseif vim.fn.exists(":SessionSave") == 2 then
							vim.cmd("SessionSave")
						else
							vim.cmd("mksession! Session.vim | echo 'Session.vim saved in cwd'")
						end
					end,
					desc = "Save session",
					mode = "n",
				},
				{
					"<leader>ql",
					function()
						if package.loaded["persisted"] then
							require("persisted").load()
						elseif vim.fn.exists(":SessionLoad") == 2 then
							vim.cmd("SessionLoad")
						elseif vim.fn.filereadable("Session.vim") == 1 then
							vim.cmd("source Session.vim")
						else
							vim.notify("No session to load", vim.log.levels.WARN)
						end
					end,
					desc = "Load session",
					mode = "n",
				},
				{
					"<leader>qd",
					function()
						if package.loaded["persisted"] then
							require("persisted").stop()
						else
							vim.notify("Persistence.nvim not active", vim.log.levels.INFO)
						end
					end,
					desc = "Disable persistence",
					mode = "n",
				},
				{
					"<leader>qq",
					function()
						vim.cmd("wall")
						if package.loaded["persisted"] then
							require("persisted").save()
						end
						vim.cmd("qa")
					end,
					desc = "Quit and save session",
					mode = "n",
				},

				----------------------------------------------------------------------
				-- HOP
				----------------------------------------------------------------------
				{
					"<leader>h",
					group = "+hop",
					cond = function()
						return pcall(require, "hop")
					end,
					mode = "n",
				},
				{
					"<leader>hw",
					"<cmd>HopWord<CR>",
					desc = "Hop word",
					cond = function()
						return pcall(require, "hop")
					end,
					mode = "n",
				},
				{
					"<leader>hc",
					"<cmd>HopChar1<CR>",
					desc = "Hop char",
					cond = function()
						return pcall(require, "hop")
					end,
					mode = "n",
				},
				{
					"<leader>hl",
					"<cmd>HopLine<CR>",
					desc = "Hop line",
					cond = function()
						return pcall(require, "hop")
					end,
					mode = "n",
				},
				{
					"<leader>hp",
					"<cmd>HopPattern<CR>",
					desc = "Hop pattern",
					cond = function()
						return pcall(require, "hop")
					end,
					mode = "n",
				},
				{
					"<leader>ha",
					"<cmd>HopAnywhere<CR>",
					desc = "Hop anywhere",
					cond = function()
						return pcall(require, "hop")
					end,
					mode = "n",
				},

				----------------------------------------------------------------------
				-- LaTeX (VimTeX)
				----------------------------------------------------------------------
				{ "<leader>x", group = "+latex", mode = "n" },
				{
					"<leader>xc",
					"<cmd>VimtexCompile<CR>",
					desc = "Compile (vimtex)",
					cond = function()
						return vim.bo.filetype == "tex"
					end,
					mode = "n",
				},
				{
					"<leader>xv",
					"<cmd>VimtexView<CR>",
					desc = "View (vimtex)",
					cond = function()
						return vim.bo.filetype == "tex"
					end,
					mode = "n",
				},
				{
					"<leader>xp",
					function()
						local pdf = vim.fn.expand("%:p:r") .. ".pdf"
						if vim.fn.filereadable(pdf) == 0 then
							vim.notify("PDF not found. Compile first (<leader>xc).", vim.log.levels.WARN)
							return
						end
						vim.fn.jobstart({ "open", "-a", "Preview", pdf }, { detach = true })
					end,
					desc = "Preview (fallback)",
					cond = function()
						return vim.bo.filetype == "tex"
					end,
					mode = "n",
				},

				----------------------------------------------------------------------
				-- MARKDOWN
				----------------------------------------------------------------------
				{ "<leader>M", group = "+markdown", mode = "n" },

				----------------------------------------------------------------------
				-- PDF TOOLS
				----------------------------------------------------------------------
				{ "<leader>P", group = "+pdf", mode = "n" },
				{
					"<leader>Pc",
					function()
						local texfile = vim.fn.expand("%:p")
						vim.fn.jobstart({ "pdflatex", texfile }, { detach = true })
						vim.notify("Compiling PDF with pdflatex…", vim.log.levels.INFO)
					end,
					desc = "Compile with pdflatex",
					cond = function()
						return vim.bo.filetype == "tex"
					end,
					mode = "n",
				},
				{
					"<leader>Po",
					function()
						local pdffile = vim.fn.expand("%:p:r") .. ".pdf"
						if vim.fn.filereadable(pdffile) == 0 then
							vim.notify("PDF not found. Compile first (<leader>Pc).", vim.log.levels.WARN)
							return
						end
						vim.fn.jobstart({ "open", pdffile }, { detach = true })
						vim.notify("Opening PDF in default viewer…", vim.log.levels.INFO)
					end,
					desc = "Open in default viewer",
					cond = function()
						return vim.bo.filetype == "tex"
					end,
					mode = "n",
				},

				----------------------------------------------------------------------
				-- RUN
				----------------------------------------------------------------------
				{ "<leader>r", group = "+run", mode = "n" },
				{
					"<leader>rr",
					function()
						if vim.o.makeprg ~= "" then
							vim.cmd("make")
						else
							vim.notify("No :make program configured", vim.log.levels.WARN)
						end
					end,
					desc = "Run :make",
					mode = "n",
				},
				{ "<leader>rl", "<cmd>make!<CR>", desc = "Run :make (silent)", mode = "n" },

				----------------------------------------------------------------------
				-- SURROUND
				----------------------------------------------------------------------
				{
					"<leader>m",
					group = "+surround",
					mode = { "n", "x" },
					cond = function()
						return package.loaded["nvim-surround"] ~= nil
					end,
				},
				{
					"<leader>mq",
					function()
						vim.cmd('normal ysiw"')
					end,
					desc = "Surround word with quotes",
					mode = "n",
				},
				{
					"<leader>mq",
					function()
						vim.cmd('normal S"')
					end,
					desc = "Surround selection with quotes",
					mode = "x",
				},
				{
					"<leader>mQ",
					function()
						vim.cmd("normal ysiw'")
					end,
					desc = "Surround word with single quotes",
					mode = "n",
				},
				{
					"<leader>mQ",
					function()
						vim.cmd("normal S'")
					end,
					desc = "Surround selection with single quotes",
					mode = "x",
				},
				{
					"<leader>mb",
					function()
						vim.cmd("normal ysiw)")
					end,
					desc = "Surround word with parentheses",
					mode = "n",
				},
				{
					"<leader>mb",
					function()
						vim.cmd("normal S)")
					end,
					desc = "Surround selection with parentheses",
					mode = "x",
				},
				{
					"<leader>mB",
					function()
						vim.cmd("normal ysiw}")
					end,
					desc = "Surround word with braces",
					mode = "n",
				},
				{
					"<leader>mB",
					function()
						vim.cmd("normal S}")
					end,
					desc = "Surround selection with braces",
					mode = "x",
				},
				{
					"<leader>ms",
					function()
						vim.cmd("normal ysiw]")
					end,
					desc = "Surround word with square brackets",
					mode = "n",
				},
				{
					"<leader>ms",
					function()
						vim.cmd("normal S]")
					end,
					desc = "Surround selection with square brackets",
					mode = "x",
				},
				{
					"<leader>mt",
					function()
						vim.cmd("normal ysiw>")
					end,
					desc = "Surround word with angle brackets",
					mode = "n",
				},
				{
					"<leader>mt",
					function()
						vim.cmd("normal S>")
					end,
					desc = "Surround selection with angle brackets",
					mode = "x",
				},
				{
					"<leader>mp",
					function()
						vim.cmd("normal ysiw`")
					end,
					desc = "Surround word with backticks",
					mode = "n",
				},
				{
					"<leader>mp",
					function()
						vim.cmd("normal S`")
					end,
					desc = "Surround selection with backticks",
					mode = "x",
				},
				{
					"<leader>md",
					desc = "Delete surround",
					function()
						local char = vim.fn.getcharstr()
						vim.cmd("normal ds" .. char)
					end,
					mode = "n",
				},
				{
					"<leader>mc",
					desc = "Change surround",
					function()
						local old = vim.fn.getcharstr()
						local new = vim.fn.getcharstr()
						vim.cmd("normal cs" .. old .. new)
					end,
					mode = "n",
				},
			},
		},

		config = function(_, opts)
			require("which-key").setup(opts)
			vim.api.nvim_create_user_command("WKDump", function()
				local state = require("which-key.state")
				vim.cmd("new")
				vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(vim.inspect(state.registry), "\n"))
			end, { desc = "Dump which-key registry for debugging" })
		end,
	},
}