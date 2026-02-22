-- ~/.config/nvim/lua/plugins/sessions.lua
-- Session management with folke/persistence.nvim (hardened)

return {
	"folke/persistence.nvim",
	event = "BufReadPre",

	opts = {
		dir = vim.fn.stdpath("state") .. "/sessions/",
		options = { "buffers", "curdir", "tabpages", "winsize", "help", "folds", "globals", "skiprtp" },
	},

	init = function()
		local function load_lazy(name)
			pcall(function()
				require("lazy").load({ plugins = { name } })
			end)
		end

		local function is_nvim_tree(buf)
			if not vim.api.nvim_buf_is_valid(buf) then
				return false
			end
			local ft = vim.bo[buf].filetype or ""
			return ft == "NvimTree"
		end

		local function is_ui_buf(buf)
			if not vim.api.nvim_buf_is_valid(buf) then
				return false
			end

			local ft = vim.bo[buf].filetype or ""
			local bt = vim.bo[buf].buftype or ""
			local name = vim.api.nvim_buf_get_name(buf) or ""

			-- Keep nvim-tree
			if ft == "NvimTree" then
				return false
			end

			-- Filetype-based (when available)
			if ft == "dap-repl" or ft:match("^dapui_") then
				return true
			end
			if ft == "neotest-summary" or ft == "neotest-output" then
				return true
			end
			if ft == "toggleterm" then
				return true
			end

			-- Buftype-based (session-restore often loses ft, but bt remains useful)
			if bt == "terminal" or bt == "prompt" or bt == "nofile" or bt == "quickfix" then
				return true
			end

			-- Name-based (this is the key fix for your screenshot)
			-- DAP UI panes commonly show up as these names after restore:
			if name:match("DAP%s+Scopes") then
				return true
			end
			if name:match("DAP%s+Stacks") then
				return true
			end
			if name:match("DAP%s+Watches") then
				return true
			end
			if name:match("DAP%s+Breakpoints") then
				return true
			end
			if name:match("DAP%s+Console") then
				return true
			end

			-- dap repl buffer often looks like “[dap-repl-9]”
			if name:match("%[dap%-repl%-%d+%]") then
				return true
			end

			-- neotest buffers sometimes restore with these names even if ft is empty
			if name:lower():match("neotest") then
				return true
			end
			if name:lower():match("summary") and bt ~= "" then
				return true
			end

			-- ToggleTerm / terminal names
			if name:match("^term://") then
				return true
			end

			return false
		end

		local function tidy_ui_now()
			-- Force-load UI plugins so their close() functions can actually detach windows
			load_lazy("nvim-dap-ui")
			load_lazy("neotest")

			-- Ask plugins to close their UI first (best case)
			pcall(function()
				require("dapui").close()
			end)
			pcall(function()
				require("neotest").summary.close()
			end)
			pcall(function()
				require("neotest").output_panel.close()
			end)

			-- Then brute-force close any windows showing UI buffers
			for _, win in ipairs(vim.api.nvim_list_wins()) do
				local buf = vim.api.nvim_win_get_buf(win)
				if not is_nvim_tree(buf) and is_ui_buf(buf) then
					pcall(vim.api.nvim_win_close, win, true)
				end
			end

			-- Finally delete UI buffers to prevent “Buffer with this name already exists” + resurrected panes
			for _, buf in ipairs(vim.api.nvim_list_bufs()) do
				if not is_nvim_tree(buf) and is_ui_buf(buf) then
					pcall(vim.api.nvim_buf_delete, buf, { force = true })
				end
			end
		end

		local function load_persistence()
			load_lazy("persistence.nvim")
			local ok, p = pcall(require, "persistence")
			if ok then
				return p
			end
			return nil
		end

		-- Expose helpers (handy for quick recovery)
		_G.SessionTidyNow = tidy_ui_now
		_G.PersistenceLoad = load_persistence

		-- Manual tidy command
		vim.api.nvim_create_user_command("SessionTidy", function()
			tidy_ui_now()
			vim.notify("Session UI tidied (dapui/neotest/toggleterm closed + buffers wiped)", vim.log.levels.INFO)
		end, {})

		-- Auto-restore when starting "nvim" in a directory (no file args)
		local grp_restore = vim.api.nvim_create_augroup("PersistenceAutoRestore", { clear = true })
		vim.api.nvim_create_autocmd("VimEnter", {
			group = grp_restore,
			callback = function()
				if vim.g.__persistence_autorestored then
					return
				end
				vim.g.__persistence_autorestored = true
				if vim.fn.argc() > 0 then
					return
				end

				local p = load_persistence()
				if not p then
					return
				end

				vim.schedule(function()
					pcall(function()
						p.load()
					end) -- cwd session
				end)
			end,
		})

		-- Auto-save on clean exit (no file args)
		local grp_save = vim.api.nvim_create_augroup("PersistenceAutoSave", { clear = true })
		vim.api.nvim_create_autocmd("VimLeavePre", {
			group = grp_save,
			callback = function()
				if vim.fn.argc() > 0 then
					return
				end

				-- CRITICAL: never save the DAP/Neotest UI layout
				tidy_ui_now()

				local p = load_persistence()
				if not p then
					return
				end
				pcall(function()
					p.save()
				end)
			end,
		})
	end,

	config = function(_, opts)
		require("persistence").setup(opts)

		vim.api.nvim_create_autocmd("User", {
			pattern = "PersistenceLoadPost",
			callback = function()
				pcall(function()
					local api = require("nvim-tree.api")
					api.tree.open()
				end)
			end,
		})
	end,

	keys = {
		{
			"<leader>qs",
			function()
				pcall(function()
					_G.SessionTidyNow()
				end)
				pcall(function()
					require("lazy").load({ plugins = { "persistence.nvim" } })
				end)
				require("persistence").save()
			end,
			desc = "Save session (tidy first)",
		},
		{
			"<leader>ql",
			function()
				pcall(function()
					require("lazy").load({ plugins = { "persistence.nvim" } })
				end)
				require("persistence").load()
			end,
			desc = "Load session (cwd)",
		},
		{
			"<leader>qL",
			function()
				pcall(function()
					require("lazy").load({ plugins = { "persistence.nvim" } })
				end)
				require("persistence").load({ last = true })
			end,
			desc = "Load last session",
		},
		{
			"<leader>qd",
			function()
				pcall(function()
					require("lazy").load({ plugins = { "persistence.nvim" } })
				end)
				require("persistence").stop()
			end,
			desc = "Disable persistence",
		},
		{
			"<leader>qq",
			function()
				vim.cmd("wall")
				pcall(function()
					_G.SessionTidyNow()
				end)
				pcall(function()
					require("lazy").load({ plugins = { "persistence.nvim" } })
				end)
				require("persistence").save()
				vim.cmd("qa")
			end,
			desc = "Quit + save session (tidy first)",
		},
	},
}
