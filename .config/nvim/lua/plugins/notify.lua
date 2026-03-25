return {
	{
		"rcarriga/nvim-notify",
		lazy = false,
		priority = 1000,
		config = function()
			local ui_notify = require("ui_notify")

			ui_notify.setup({
				timeout = 5000,
				fade_ms = 300,
				max_width = 80,
				border = "rounded",
			})

			vim.notify = function(msg, level, opts)
				return ui_notify.notify(msg, level, opts)
			end

			_G.CodexNotifyPlacement = {
				get = function()
					return ui_notify.get_placement()
				end,
				set = function(name)
					return ui_notify.set_placement(name)
				end,
			}
		end,
	},
}

