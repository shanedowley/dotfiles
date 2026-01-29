-- ~/.config/nvim/lua/plugins/whichkey.lua
return {
	{
		"folke/which-key.nvim",
		event = "VeryLazy",

		init = function()
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
			show_help = false,
			show_keys = true,
			icons = { mappings = false },

			triggers = {
				{ "<leader>", mode = "n" },
				{ "<leader>", mode = "v" },
				{ "<leader>", mode = "x" },
			},

			spec = {
				----------------------------------------------------------------------
				-- FILE
				----------------------------------------------------------------------
				{ "<leader>f", group = "+file" },
				{ "<leader>fe", "<cmd>NvimTreeToggle<CR>", desc = "Explorer" },
				{ "<leader>ff", "<cmd>Telescope find_files<CR>", desc = "Find file" },
				{ "<leader>fg", "<cmd>Telescope live_grep<CR>", desc = "Live grep" },
				{ "<leader>fr", "<cmd>Telescope oldfiles<CR>", desc = "Recent files" },
				{ "<leader>fs", "<cmd>w<CR>", desc = "Save file" },
				{ "<leader>fS", "<cmd>wa<CR>", desc = "Save all" },
				{ "<leader>fn", "<cmd>enew<CR>", desc = "New file" },

				----------------------------------------------------------------------
				-- BUFFERS
				----------------------------------------------------------------------
				{ "<leader>b", group = "+buffer" },
				{ "<leader>bb", "<cmd>Telescope buffers<CR>", desc = "List buffers" },
				{ "<leader>bn", "<cmd>bnext<CR>", desc = "Next buffer" },
				{ "<leader>bp", "<cmd>bprevious<CR>", desc = "Prev buffer" },
				{ "<leader>bd", "<cmd>bd<CR>", desc = "Delete buffer" },

				----------------------------------------------------------------------
				-- ALTERNATE
				----------------------------------------------------------------------
				{ "<leader>a", group = "+alternate" },
				{ "<leader>ac", "<cmd>GoToCSS<CR>", desc = "Go to CSS file" },
				{ "<leader>ah", "<cmd>GoToHTML<CR>", desc = "Go to HTML file" },

				----------------------------------------------------------------------
				-- WINDOWS
				----------------------------------------------------------------------
				{ "<leader>w", group = "+window" },
				{ "<leader>wh", "<C-w>h", desc = "Go left" },
				{ "<leader>wj", "<C-w>j", desc = "Go down" },
				{ "<leader>wk", "<C-w>k", desc = "Go up" },
				{ "<leader>wl", "<C-w>l", desc = "Go right" },
				{ "<leader>wv", "<cmd>vsplit<CR>", desc = "Vertical split" },
				{ "<leader>ws", "<cmd>split<CR>", desc = "Horizontal split" },
				{ "<leader>wq", "<cmd>q<CR>", desc = "Close window" },
				{ "<leader>w=", "<C-w>=", desc = "Equalize sizes" },
				{ "<leader>w+", "<cmd>vertical resize +5<CR>", desc = "Increase width (+5)" },
				{ "<leader>w-", "<cmd>vertical resize -5<CR>", desc = "Decrease width (-5)" },
				{ "<leader>w>", "<cmd>resize +3<CR>", desc = "Increase height (+3)" },
				{ "<leader>w<", "<cmd>resize -3<CR>", desc = "Decrease height (-3)" },

				----------------------------------------------------------------------
				-- GIT
				----------------------------------------------------------------------
				{ "<leader>g", group = "+git" },
				{ "<leader>gb", "<cmd>Gitsigns blame_line<CR>", desc = "Blame line" },
				{ "<leader>gB", "<cmd>Git blame<CR>", desc = "Git: blame (split)" },
				{ "<leader>gd", "<cmd>Gitsigns diffthis<CR>", desc = "Diff file" },
				{ "<leader>gg", "<cmd>Git<CR>", desc = "Git: status (Fugitive)" },
				{ "<leader>gl", "<cmd>LazyGitIterm<CR>", desc = "Git: Lazygit (iTerm2 tab)" },
				{ "<leader>gn", "<cmd>Gitsigns next_hunk<CR>", desc = "Next hunk" },
				{ "<leader>gN", "<cmd>Gitsigns prev_hunk<CR>", desc = "Prev hunk" },
				{ "<leader>gr", "<cmd>Gitsigns reset_hunk<CR>", desc = "Reset hunk" },
				{ "<leader>gs", "<cmd>Gitsigns stage_hunk<CR>", desc = "Stage hunk" },
				{
					"<leader>gu",
					function()
						require("gitsigns").undo_stage_hunk()
					end,
					desc = "Undo stage hunk",
				},
				{
					"<leader>gp",
					function()
						require("gitsigns").preview_hunk()
					end,
					desc = "Preview hunk",
				},

				----------------------------------------------------------------------
				-- UI
				----------------------------------------------------------------------
				{ "<leader>u", group = "+ui" },
				{ "<leader>ut", desc = "Switch color scheme" },

				----------------------------------------------------------------------
				-- LSP
				----------------------------------------------------------------------
				{ "<leader>l", group = "+lsp" },
				{
					"<leader>ld",
					function()
						vim.lsp.buf.definition()
					end,
					desc = "Definition",
				},
				{
					"<leader>lD",
					function()
						vim.lsp.buf.declaration()
					end,
					desc = "Declaration",
				},
				{
					"<leader>lr",
					function()
						vim.lsp.buf.rename()
					end,
					desc = "Rename",
				},
				{
					"<leader>la",
					function()
						vim.lsp.buf.code_action()
					end,
					desc = "Code action",
				},
				{
					"<leader>lh",
					function()
						vim.lsp.buf.hover()
					end,
					desc = "Hover docs",
				},
				{
					"<leader>li",
					function()
						vim.lsp.buf.implementation()
					end,
					desc = "Implementation",
				},
				{
					"<leader>lt",
					function()
						vim.lsp.buf.type_definition()
					end,
					desc = "Type def",
				},
				{
					"<leader>lf",
					function()
						vim.lsp.buf.format({ async = true })
					end,
					desc = "Format",
				},
				{ "<leader>ls", "<cmd>Telescope lsp_document_symbols<CR>", desc = "Document symbols" },
				{ "<leader>lS", "<cmd>Telescope lsp_dynamic_workspace_symbols<CR>", desc = "Workspace symbols" },
				{
					"<leader>le",
					function()
						vim.diagnostic.open_float()
					end,
					desc = "Line diagnostics",
				},
				{
					"<leader>l]",
					function()
						vim.diagnostic.goto_next()
					end,
					desc = "Next diagnostic",
				},
				{
					"<leader>l[",
					function()
						vim.diagnostic.goto_prev()
					end,
					desc = "Prev diagnostic",
				},

				----------------------------------------------------------------------
				-- CODEX
				----------------------------------------------------------------------
				{ "<leader>c", group = "+codex" },
				{ "<leader>cf", desc = "Run on entire file" },
				{ "<leader>cl", desc = "Run on current line" },
				{ "<leader>cc", desc = "Run on selection" },
				{ "<leader>cp", desc = "Patch file (diff)" },
				{ "<leader>cs", desc = "Scratchpad prompt" },

				----------------------------------------------------------------------
				-- DEBUG
				----------------------------------------------------------------------
				{ "<leader>d", group = "+debug" },
				{ "<leader>db", "<cmd>DapToggleBreakpoint<CR>", desc = "Toggle breakpoint" },
				{
					"<leader>dB",
					"<cmd>lua require('dap').set_breakpoint(vim.fn.input('Breakpoint condition: '))<CR>",
					desc = "Conditional breakpoint",
				},
				{ "<leader>dc", "<cmd>DapContinue<CR>", desc = "Continue" },
				{ "<leader>do", "<cmd>DapStepOver<CR>", desc = "Step over" },
				{ "<leader>di", "<cmd>DapStepInto<CR>", desc = "Step into" },
				{ "<leader>dO", "<cmd>DapStepOut<CR>", desc = "Step out" },
				{
					"<leader>dr",
					"<cmd>DapRestartFrame<CR>",
					desc = "Restart frame",
					cond = function()
						return pcall(require, "dap")
					end,
				},
				{ "<leader>dx", "<cmd>lua require('dap').terminate()<CR>", desc = "Terminate" },
				{ "<leader>dl", "<cmd>lua require('dap').run_last()<CR>", desc = "Run last" },
				{ "<leader>dh", "<cmd>lua require('dap.ui.widgets').hover()<CR>", desc = "Hover variables" },
				{ "<leader>dp", "<cmd>lua require('dap.ui.widgets').preview()<CR>", desc = "Preview variable" },
				{
					"<leader>df",
					"<cmd>lua local w=require('dap.ui.widgets');w.centered_float(w.frames)<CR>",
					desc = "Show frames",
				},
				{
					"<leader>ds",
					"<cmd>lua local w=require('dap.ui.widgets');w.centered_float(w.scopes)<CR>",
					desc = "Show scopes",
				},
				{ "<leader>de", "<cmd>lua require('dapui').eval()<CR>", desc = "Eval expression" },
				{
					"<leader>du",
					function()
						local ok, dapui = pcall(require, "dapui")
						if ok then
							dapui.toggle()
						else
							vim.notify("dap-ui not installed", vim.log.levels.WARN)
						end
					end,
					desc = "Toggle DAP UI",
				},

				----------------------------------------------------------------------
				-- TEST
				----------------------------------------------------------------------
				{ "<leader>t", group = "+test" },
				{
					"<leader>tn",
					function()
						require("neotest").run.run()
					end,
					desc = "Run nearest",
					cond = function()
						return package.loaded["neotest"]
					end,
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
				},

				----------------------------------------------------------------------
				-- SESSIONS
				----------------------------------------------------------------------
				{ "<leader>q", group = "+sessions" },
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
				},
				{
					"<leader>hw",
					"<cmd>HopWord<CR>",
					desc = "Hop word",
					cond = function()
						return pcall(require, "hop")
					end,
				},
				{
					"<leader>hc",
					"<cmd>HopChar1<CR>",
					desc = "Hop char",
					cond = function()
						return pcall(require, "hop")
					end,
				},
				{
					"<leader>hl",
					"<cmd>HopLine<CR>",
					desc = "Hop line",
					cond = function()
						return pcall(require, "hop")
					end,
				},
				{
					"<leader>hp",
					"<cmd>HopPattern<CR>",
					desc = "Hop pattern",
					cond = function()
						return pcall(require, "hop")
					end,
				},
				{
					"<leader>ha",
					"<cmd>HopAnywhere<CR>",
					desc = "Hop anywhere",
					cond = function()
						return pcall(require, "hop")
					end,
				},

				----------------------------------------------------------------------
				-- LaTeX (VimTeX)
				----------------------------------------------------------------------
				{ "<leader>x", group = "+latex" },
				{
					"<leader>xc",
					"<cmd>VimtexCompile<CR>",
					desc = "Compile (vimtex)",
					cond = function()
						return vim.bo.filetype == "tex"
					end,
				},
				{
					"<leader>xv",
					"<cmd>VimtexView<CR>",
					desc = "View (vimtex)",
					cond = function()
						return vim.bo.filetype == "tex"
					end,
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
				},

				----------------------------------------------------------------------
				-- MARKDOWN
				----------------------------------------------------------------------
				{ "<leader>M", group = "+markdown" },
				{
					"<leader>Mp",
					"<cmd>MarkdownPreviewToggle<CR>",
					desc = "Toggle Preview",
					cond = function()
						return vim.bo.filetype == "markdown"
					end,
				},
				{
					"<leader>Ms",
					"<cmd>MarkdownPreviewStop<CR>",
					desc = "Stop preview",
					cond = function()
						return vim.bo.filetype == "markdown"
					end,
				},

				----------------------------------------------------------------------
				-- PDF TOOLS
				----------------------------------------------------------------------
				{ "<leader>P", group = "+pdf" },
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
				},
				----------------------------------------------------------------------
				-- RUN
				----------------------------------------------------------------------
				{ "<leader>r", group = "+run" },
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
				},
				{ "<leader>rl", "<cmd>make!<CR>", desc = "Run :make (silent)" },

				----------------------------------------------------------------------
				-- SURROUND
				----------------------------------------------------------------------
				{
					"<leader>m",
					group = "+surround",
					mode = { "n", "v" },
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
					mode = "v",
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
					mode = "v",
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
					mode = "v",
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
					mode = "v",
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
					mode = "v",
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
					mode = "v",
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
					mode = "v",
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
