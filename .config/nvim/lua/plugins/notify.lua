return {
	{
		"rcarriga/nvim-notify",
		lazy = false,
		priority = 1000,
		config = function()
			local notify = require("notify")
			notify.setup({
				timeout = 1500,
				render = "minimal",
				stages = "fade_in_slide_out",
			})
			vim.notify = notify
		end,
	},
}
