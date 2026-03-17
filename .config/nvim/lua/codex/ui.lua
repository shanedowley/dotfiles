local M = {}

local uv = vim.uv or vim.loop

local spinner = {
	timer = nil,
	idx = 1,
	notif = nil,
	active = false,
}

local frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }

function M.start(msg)
	if spinner.timer then
		pcall(spinner.timer.stop, spinner.timer)
		pcall(spinner.timer.close, spinner.timer)
		spinner.timer = nil
	end

	spinner.active = true
	spinner.idx = 1

	local ok_notify, notify = pcall(require, "notify")
	if ok_notify then
		spinner.notif = notify(msg .. " " .. frames[spinner.idx], vim.log.levels.INFO, {
			title = "Codex",
			timeout = false,
		})
	else
		vim.api.nvim_echo({ { msg .. " " .. frames[spinner.idx], "ModeMsg" } }, false, {})
	end

	spinner.timer = uv.new_timer()
	spinner.timer:start(
		120,
		120,
		vim.schedule_wrap(function()
			if not spinner.active then
				return
			end
			spinner.idx = (spinner.idx % #frames) + 1
			local text = msg .. " " .. frames[spinner.idx]

			local ok2, notify2 = pcall(require, "notify")
			if ok2 then
				spinner.notif = notify2(text, vim.log.levels.INFO, {
					title = "Codex",
					timeout = false,
					replace = spinner.notif,
				})
			else
				vim.api.nvim_echo({ { text, "ModeMsg" } }, false, {})
			end
		end)
	)
end

function M.stop(msg, level)
	spinner.active = false
	if spinner.timer then
		spinner.timer:stop()
		spinner.timer:close()
		spinner.timer = nil
	end

	local ok_notify, notify = pcall(require, "notify")
	if ok_notify then
		notify(msg, level or vim.log.levels.INFO, {
			title = "Codex",
			timeout = 1500,
			replace = spinner.notif,
		})
	else
		vim.api.nvim_echo({ { msg, "ModeMsg" } }, false, {})
		vim.defer_fn(function()
			vim.api.nvim_echo({ { "" } }, false, {})
		end, 1200)
	end
end

return M
