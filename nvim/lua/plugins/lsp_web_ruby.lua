-- Web + Ruby LSPs (migrated to vim.lsp.config API)
return {
	{
		"neovim/nvim-lspconfig",
		ft = { "ruby" },
		dependencies = {
			"hrsh7th/cmp-nvim-lsp", -- optional
		},
		config = function()
			-- Capabilities (optionally enhanced by nvim-cmp)
			local caps = vim.lsp.protocol.make_client_capabilities()
			local ok_cmp, cmp_lsp = pcall(require, "cmp_nvim_lsp")
			if ok_cmp then
				caps = cmp_lsp.default_capabilities(caps)
			end

			local function root_with(markers)
				return function(fname)
					return vim.fs.root(fname, markers) or vim.fn.getcwd()
				end
			end

			-- Prefer ruby-lsp if present; otherwise fall back to solargraph
			vim.lsp.config["ruby_lsp"] = {
				name = "ruby_lsp",
				cmd = (function()
					-- Prefer Bundler if a Gemfile is present in the project
					local gemfile = vim.fn.findfile("Gemfile", ".;")
					if gemfile ~= "" then
						return { "bundle", "exec", "ruby-lsp" }
					end
					-- Otherwise fall back to global binary
					return { "ruby-lsp" }
				end)(),
				capabilities = caps,
				filetypes = { "ruby" },
				root_dir = root_with({ "Gemfile", ".git" }),
			}

			vim.lsp.config["solargraph"] = {
				name = "solargraph",
				cmd = { "solargraph", "stdio" }, -- `gem install solargraph`
				capabilities = caps,
				filetypes = { "ruby" },
				root_dir = root_with({ "Gemfile", ".git" }),
				init_options = { formatting = true },
			}

			-- Start whichever server is available for Ruby buffers
			vim.api.nvim_create_autocmd("FileType", {
				pattern = "ruby",
				callback = function(ev)
					local fname = vim.api.nvim_buf_get_name(ev.buf)
					-- Skip if already attached
					if next(vim.lsp.get_clients({ bufnr = ev.buf, name = "ruby_lsp" })) then
						return
					end
					if next(vim.lsp.get_clients({ bufnr = ev.buf, name = "solargraph" })) then
						return
					end

					local function start_if(cmd_name, key)
						if vim.fn.executable(cmd_name) == 1 then
							local cfg = vim.tbl_deep_extend("force", {}, vim.lsp.config[key])
							cfg.root_dir = cfg.root_dir(fname)
							vim.lsp.start(cfg)
							return true
						end
						return false
					end

					if not start_if("ruby-lsp", "ruby_lsp") then
						start_if("solargraph", "solargraph")
					end
				end,
			})
		end,
	},
}
