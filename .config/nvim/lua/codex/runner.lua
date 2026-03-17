-- ~/.config/nvim/lua/codex/runner.lua
local M = {}

local uv = vim.uv or vim.loop

local spinner = {
	timer = nil,
	idx = 1,
	notif = nil,
	active = false,
}

local frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }

local function log_event(event, data)
	local ok, codex_log = pcall(require, "codex_log")
	if not ok or type(codex_log) ~= "table" then
		return
	end

	if type(codex_log.event) == "function" then
		pcall(codex_log.event, event, data)
	elseif type(codex_log.write) == "function" then
		pcall(codex_log.write, event, data)
	elseif type(codex_log.append) == "function" then
		pcall(codex_log.append, {
			event = event,
			data = data,
			ts = os.date("!%Y-%m-%dT%H:%M:%SZ"),
		})
	end
end

local function ui_start(msg)
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

local function ui_stop(msg, level)
	spinner.active = false

	if spinner.timer then
		pcall(spinner.timer.stop, spinner.timer)
		pcall(spinner.timer.close, spinner.timer)
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

local function hrtime_ms(start_ns)
	return math.floor((uv.hrtime() - start_ns) / 1e6)
end

local function normalize_lines(lines)
	local out = {}
	for _, l in ipairs(lines or {}) do
		if l ~= nil then
			out[#out + 1] = (l:gsub("\r", ""))
		end
	end
	return out
end

local function fence_lang(filetype)
	local ok, prompt = pcall(require, "codex_prompt")
	if ok and type(prompt) == "table" and type(prompt.fence_lang) == "function" then
		return prompt.fence_lang(filetype or "")
	end
	return filetype or ""
end

function M.run(opts)
	opts = opts or {}

	local prompt_text = opts.prompt
	if not prompt_text or prompt_text == "" then
		vim.notify("Codex runner: missing prompt", vim.log.levels.ERROR, { title = "Codex" })
		return
	end

	local input = opts.input
	local spinner_message = opts.spinner_message or "Codex working…"
	local out_stdout, out_stderr = {}, {}
	local started_ns = uv.hrtime()
	local op = opts.op or "codex_run"

	ui_start(spinner_message)

	log_event("start", {
		op = op,
		prompt_len = #prompt_text,
		input_len = input and #input or 0,
		filetype = opts.filetype,
		embedded = opts.embedded or false,
	})

	local argv = { "codex", "exec", "--skip-git-repo-check", prompt_text }

	local job_id = vim.fn.jobstart(argv, {
		pty = opts.pty or false,
		env = opts.env,
		stdout_buffered = true,
		stderr_buffered = true,

		on_stdout = function(_, data)
			if data then
				vim.list_extend(out_stdout, data)
			end
		end,

		on_stderr = function(_, data)
			if data then
				vim.list_extend(out_stderr, data)
			end
		end,

		on_exit = function(_, code)
			vim.schedule(function()
				local latency_ms = hrtime_ms(started_ns)
				local stdout = normalize_lines(out_stdout)
				local stderr = normalize_lines(out_stderr)

				local result = {
					code = code,
					stdout = stdout,
					stderr = stderr,
					output = (#stdout > 0) and stdout or stderr,
					latency_ms = latency_ms,
					op = op,
				}

				if code ~= 0 then
					ui_stop("Codex failed (see output)", vim.log.levels.ERROR)

					log_event("error", {
						op = op,
						code = code,
						latency_ms = latency_ms,
						stdout_lines = #stdout,
						stderr_lines = #stderr,
					})

					log_event("latency", {
						op = op,
						stage = "codex_exec",
						elapsed_ms = latency_ms,
						result = "FAIL",
						filetype = opts.filetype,
					})

					if opts.on_failure then
						opts.on_failure(result)
					end
					return
				end

				ui_stop("Codex done", vim.log.levels.INFO)

				log_event("response", {
					op = op,
					bytes = #table.concat(result.output, "\n"),
				})

				log_event("latency", {
					op = op,
					stage = "codex_exec",
					elapsed_ms = latency_ms,
					result = "PASS",
					filetype = opts.filetype,
				})

				if opts.on_success then
					opts.on_success(result)
				end
			end)
		end,
	})

	if job_id <= 0 then
		ui_stop("Failed to start Codex job", vim.log.levels.ERROR)

		log_event("error", {
			op = op,
			reason = "jobstart_failed",
			result = tostring(job_id),
			prompt_len = #prompt_text,
			input_len = input and #input or 0,
		})

		if opts.on_failure then
			opts.on_failure({
				code = -1,
				stdout = {},
				stderr = {},
				output = {},
				latency_ms = 0,
				op = op,
			})
		end
		return
	end

	if input and input ~= "" then
		vim.fn.chansend(job_id, input .. "\n")
	end
	vim.fn.chanclose(job_id, "stdin")
end

function M.run_embedded(input, instruction, opts)
	opts = opts or {}

	local lang = fence_lang(opts.filetype)
	local prompt_text = instruction .. "\n\n---\nHere is the code/snippet:\n```" .. lang .. "\n" .. input .. "\n```"

	local env = opts.env or {
		PAGER = "cat",
		GIT_PAGER = "cat",
		LESS = "-FRSX",
		NO_COLOR = "1",
		TERM = "xterm-256color",
	}

	M.run(vim.tbl_extend("force", opts, {
		prompt = prompt_text,
		input = nil,
		pty = true,
		env = env,
		embedded = true,
	}))
end

return M