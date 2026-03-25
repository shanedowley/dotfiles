local M = {}

local uv = vim.uv or vim.loop

local allowed = {
	top_left = true,
	top_right = true,
	center = true,
	bottom_left = true,
	bottom_right = true,
}

local state = {
	placement = "top_right",
	win = nil,
	buf = nil,
	timer = nil,
	fade_timer = nil,
	active_id = nil,
	next_id = 0,
	timeout = 5000,
	fade_ms = 300,
	border = "rounded",
	padding_x = 2,
	padding_y = 0,
	max_width = 80,
	last_level = vim.log.levels.INFO,
}

local function placement_path()
	return vim.fn.stdpath("state") .. "/codex_notify_placement.txt"
end

local function read_saved_placement()
	local path = placement_path()
	if vim.fn.filereadable(path) ~= 1 then
		return nil
	end

	local ok, lines = pcall(vim.fn.readfile, path)
	if not ok or not lines or #lines == 0 then
		return nil
	end

	local value = vim.trim(lines[1] or "")
	if allowed[value] then
		return value
	end

	return nil
end

local function write_saved_placement(value)
	local path = placement_path()
	pcall(vim.fn.mkdir, vim.fn.fnamemodify(path, ":h"), "p")
	return pcall(vim.fn.writefile, { value }, path)
end

local function stop_timer(timer)
	if timer then
		pcall(timer.stop, timer)
		pcall(timer.close, timer)
	end
end

local function cleanup_timers()
	if state.timer then
		stop_timer(state.timer)
		state.timer = nil
	end
	if state.fade_timer then
		stop_timer(state.fade_timer)
		state.fade_timer = nil
	end
end

local function valid_buf(buf)
	return buf and vim.api.nvim_buf_is_valid(buf)
end

local function valid_win(win)
	return win and vim.api.nvim_win_is_valid(win)
end

local function close_window()
	if valid_win(state.win) then
		pcall(vim.api.nvim_win_close, state.win, true)
	end
	state.win = nil
	state.buf = nil
	state.active_id = nil
end

local function ensure_buf()
	if valid_buf(state.buf) then
		return state.buf
	end

	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].swapfile = false
	vim.bo[buf].modifiable = true
	vim.bo[buf].filetype = "markdown"
	state.buf = buf
	return buf
end

local function normalize_lines(msg)
	local lines = vim.split(tostring(msg or ""), "\n", { plain = true })
	if #lines == 0 then
		lines = { "" }
	end
	return lines
end

local function clamp_width(lines)
	local max_line = 1
	for _, line in ipairs(lines) do
		local w = vim.fn.strdisplaywidth(line)
		if w > max_line then
			max_line = w
		end
	end
	return math.min(max_line, state.max_width)
end

local function content_size(lines)
	local width = clamp_width(lines)
	local height = #lines
	return width, height
end

local function editor_size()
	return vim.o.columns, vim.o.lines
end

local function placement_position(width, height)
	local cols, lines = editor_size()

	local win_width = width + (state.padding_x * 2)
	local win_height = height + (state.padding_y * 2)

	local row
	local col

	if state.placement == "top_left" then
		row = 1
		col = 1
	elseif state.placement == "top_right" then
		row = 1
		col = math.max(0, cols - win_width - 1)
	elseif state.placement == "center" then
		row = math.max(0, math.floor((lines - win_height) / 2) - 1)
		col = math.max(0, math.floor((cols - win_width) / 2))
	elseif state.placement == "bottom_left" then
		row = math.max(0, lines - win_height - 3)
		col = 1
	elseif state.placement == "bottom_right" then
		row = math.max(0, lines - win_height - 3)
		col = math.max(0, cols - win_width - 1)
	else
		row = 1
		col = math.max(0, cols - win_width - 1)
	end

	return {
		relative = "editor",
		style = "minimal",
		border = state.border,
		row = row,
		col = col,
		width = win_width,
		height = win_height,
		noautocmd = true,
		focusable = false,
		zindex = 220,
	}
end

local function highlight_for_level(level)
	if level == vim.log.levels.ERROR then
		return "DiagnosticFloatingError"
	end
	if level == vim.log.levels.WARN then
		return "DiagnosticFloatingWarn"
	end
	if level == vim.log.levels.INFO then
		return "DiagnosticFloatingInfo"
	end
	return "NormalFloat"
end

local function get_hl(name, fallback)
	local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
	if ok and hl and next(hl) ~= nil then
		return hl
	end
	if fallback and fallback ~= name then
		local ok2, hl2 = pcall(vim.api.nvim_get_hl, 0, { name = fallback, link = false })
		if ok2 and hl2 then
			return hl2
		end
	end
	return {}
end

local function int_to_rgb(n)
	if not n then
		return nil
	end
	return {
		r = bit.rshift(n, 16) % 256,
		g = bit.rshift(n, 8) % 256,
		b = n % 256,
	}
end

local function rgb_to_int(rgb)
	if not rgb then
		return nil
	end
	return bit.lshift(rgb.r, 16) + bit.lshift(rgb.g, 8) + rgb.b
end

local function blend_channel(a, b, t)
	return math.floor(a + ((b - a) * t) + 0.5)
end

local function blend_color(from_int, to_int, t)
	local from = int_to_rgb(from_int)
	local to = int_to_rgb(to_int)
	if not from and not to then
		return nil
	end
	if not from then
		from = to
	end
	if not to then
		to = from
	end
	return rgb_to_int({
		r = blend_channel(from.r, to.r, t),
		g = blend_channel(from.g, to.g, t),
		b = blend_channel(from.b, to.b, t),
	})
end

local function fade_group_names(level, step_key)
	local prefix = "UiNotify"
	if level == vim.log.levels.ERROR then
		prefix = prefix .. "Error"
	elseif level == vim.log.levels.WARN then
		prefix = prefix .. "Warn"
	elseif level == vim.log.levels.INFO then
		prefix = prefix .. "Info"
	else
		prefix = prefix .. "Normal"
	end

	return prefix .. "Float" .. step_key, prefix .. "Border" .. step_key
end

local function apply_window_style(win, level, fade_t)
	fade_t = fade_t or 0

	local base_name = highlight_for_level(level)
	local base_float = get_hl(base_name, "NormalFloat")
	local base_border = get_hl("FloatBorder", "FloatBorder")
	local normal = get_hl("Normal", "Normal")

	local target_bg = normal.bg or base_float.bg or 0x000000
	local target_fg = target_bg
	local target_border = target_bg

	local float_fg = blend_color(base_float.fg, target_fg, fade_t)
	local float_bg = blend_color(base_float.bg, target_bg, fade_t)
	local border_fg = blend_color(base_border.fg or base_float.fg, target_border, fade_t)
	local border_bg = blend_color(base_border.bg or base_float.bg, target_bg, fade_t)

	local step_key = tostring(math.floor(fade_t * 100))
	local float_group, border_group = fade_group_names(level, step_key)

	vim.api.nvim_set_hl(0, float_group, {
		fg = float_fg,
		bg = float_bg,
		bold = base_float.bold,
		italic = base_float.italic,
	})

	vim.api.nvim_set_hl(0, border_group, {
		fg = border_fg,
		bg = border_bg,
		bold = base_border.bold,
		italic = base_border.italic,
	})

	pcall(vim.api.nvim_win_set_option, win, "winblend", 0)
	pcall(vim.api.nvim_win_set_option, win, "wrap", false)
	pcall(vim.api.nvim_win_set_option, win, "cursorline", false)

	pcall(vim.api.nvim_win_set_option, win, "winhl", table.concat({
		"NormalFloat:" .. float_group,
		"FloatBorder:" .. border_group,
	}, ","))
end

local function render_lines(buf, msg)
	local lines = normalize_lines(msg)
	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
	return lines
end

local function open_or_update(msg, level)
	local buf = ensure_buf()
	local lines = render_lines(buf, msg)
	local width, height = content_size(lines)
	local cfg = placement_position(width, height)

	if valid_win(state.win) then
		pcall(vim.api.nvim_win_set_config, state.win, cfg)
	else
		state.win = vim.api.nvim_open_win(buf, false, cfg)
	end

	state.last_level = level
	apply_window_style(state.win, level, 0)
end

local function begin_timeout(id, timeout)
	if timeout == false then
		return
	end

	timeout = timeout or state.timeout

	if state.timer then
		stop_timer(state.timer)
		state.timer = nil
	end

	state.timer = uv.new_timer()
	state.timer:start(timeout, 0, vim.schedule_wrap(function()
		if state.active_id ~= id then
			return
		end
		M.dismiss(id)
	end))
end

local function fade_and_close(id)
	if state.fade_timer then
		stop_timer(state.fade_timer)
		state.fade_timer = nil
	end

	if not valid_win(state.win) then
		close_window()
		return
	end

	local steps = 10
	local interval = math.max(16, math.floor(state.fade_ms / steps))
	local current = 0
	local level = state.last_level or vim.log.levels.INFO

	state.fade_timer = uv.new_timer()
	state.fade_timer:start(interval, interval, vim.schedule_wrap(function()
		if state.active_id ~= id or not valid_win(state.win) then
			stop_timer(state.fade_timer)
			state.fade_timer = nil
			return
		end

		current = current + 1
		local t = math.min(1, current / steps)
		apply_window_style(state.win, level, t)

		if current >= steps then
			stop_timer(state.fade_timer)
			state.fade_timer = nil
			close_window()
		end
	end))
end

function M.notify(msg, level, opts)
	opts = opts or {}
	level = level or vim.log.levels.INFO

	cleanup_timers()

	state.next_id = state.next_id + 1
	local id = state.next_id
	state.active_id = id

	open_or_update(msg, level)
	begin_timeout(id, opts.timeout ~= nil and opts.timeout or state.timeout)

	return id
end

function M.update(id, msg, level, opts)
	opts = opts or {}
	level = level or vim.log.levels.INFO

	if not id or state.active_id ~= id then
		return M.notify(msg, level, opts)
	end

	cleanup_timers()
	open_or_update(msg, level)
	begin_timeout(id, opts.timeout ~= nil and opts.timeout or state.timeout)

	return id
end

function M.dismiss(id)
	if id and state.active_id ~= id then
		return
	end

	if not state.active_id then
		return
	end

	if state.timer then
		stop_timer(state.timer)
		state.timer = nil
	end

	fade_and_close(state.active_id)
end

function M.set_placement(name)
	if not allowed[name] then
		return false, "Invalid placement: " .. tostring(name)
	end

	state.placement = name
	local ok = write_saved_placement(name)
	if not ok then
		return false, "Placement set, but failed to persist it"
	end

	if valid_win(state.win) and valid_buf(state.buf) then
		local lines = vim.api.nvim_buf_get_lines(state.buf, 0, -1, false)
		local width, height = content_size(lines)
		local cfg = placement_position(width, height)
		pcall(vim.api.nvim_win_set_config, state.win, cfg)
	end

	return true, state.placement
end

function M.get_placement()
	return state.placement
end

function M.setup(opts)
	opts = opts or {}
	state.timeout = opts.timeout or state.timeout
	state.fade_ms = opts.fade_ms or state.fade_ms
	state.max_width = opts.max_width or state.max_width
	state.border = opts.border or state.border
	state.placement = read_saved_placement() or state.placement
end

M.setup()

return M