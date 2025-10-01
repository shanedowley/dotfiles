-- Core LSPs (migrated to vim.lsp.config API)
return {
	{
		"neovim/nvim-lspconfig",
		event = { "BufReadPre", "BufNewFile" },
		dependencies = {
			"hrsh7th/cmp-nvim-lsp", -- optional: enhance completion capabilities
		},
		config = function()
			-- Capabilities (optionally enhanced by nvim-cmp)
			local caps = vim.lsp.protocol.make_client_capabilities()
			local ok_cmp, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
			if ok_cmp then
				caps = cmp_nvim_lsp.default_capabilities(caps)
			end

			-- Optional: rounded borders for hover/signature windows
			local border = "rounded"
			vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, { border = border })
			vim.lsp.handlers["textDocument/signatureHelp"] =
				vim.lsp.with(vim.lsp.handlers.signature_help, { border = border })

			-- Helper: project root detection with vim.fs.root
			local function root_with(markers)
				return function(fname)
					return vim.fs.root(fname, markers) or vim.fn.getcwd()
				end
			end

			-- =========================
			-- C/C++: clangd
			-- =========================
			vim.lsp.config["clangd"] = {
				name = "clangd",
				cmd = { "clangd" },
				capabilities = caps,
				filetypes = { "c", "cpp", "objc", "objcpp" },
				root_dir = root_with({ "compile_commands.json", "compile_flags.txt", ".git" }),
			}

			-- Auto-start clangd on matching filetypes
			vim.api.nvim_create_autocmd("FileType", {
				pattern = { "c", "cpp", "objc", "objcpp" },
				callback = function(ev)
					-- Avoid duplicates
					local existing = vim.lsp.get_clients({ bufnr = ev.buf, name = "clangd" })
					if #existing > 0 then
						return
					end
					local cfg = vim.tbl_deep_extend("force", {}, vim.lsp.config["clangd"])
					cfg.root_dir = cfg.root_dir(vim.api.nvim_buf_get_name(ev.buf))
					vim.lsp.start(cfg)
				end,
			})
		end,
	},
}
