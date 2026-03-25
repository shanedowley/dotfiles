local M = {}

local function log_path()
	return vim.fn.expand(vim.fn.stdpath("state") .. "/codex.log")
end

local function parse_kv_line(line)
	local item = {}

	for key, value in line:gmatch("([%w_]+)=([^%s]+)") do
		item[key] = value
	end

	return item
end

local function read_log_lines()
	local path = log_path()

	if vim.fn.filereadable(path) ~= 1 then
		return nil, "Codex log file not found: " .. path
	end

	local ok, lines = pcall(vim.fn.readfile, path)
	if not ok or not lines then
		return nil, "Failed to read Codex log: " .. path
	end

	return lines, nil
end

local function tonumber_or_nil(x)
	return tonumber(x)
end

local function find_latest_op_latency_index(lines)
	for i = #lines, 1, -1 do
		local line = lines[i]
		if line:find("event=latency", 1, true) and line:find(" op=", 1, true) then
			local item = parse_kv_line(line)
			if item.event == "latency" and item.op and item.op ~= "" then
				return i, item
			end
		end
	end
	return nil, nil
end

function M.read_latest()
	local lines, err = read_log_lines()
	if not lines then
		return nil, err
	end

	if #lines == 0 then
		return nil, "Codex log is empty"
	end

	local anchor_index, anchor = find_latest_op_latency_index(lines)
	if not anchor_index or not anchor then
		return nil, "No latency events with operation name found in Codex log"
	end

	local out = {
		op = anchor.op or "unknown",
		result = anchor.result or "-",
		codex_exec_ms = nil,
		validate_ms = nil,
		total_ms = nil,
	}

	for i = anchor_index, 1, -1 do
		local line = lines[i]
		if line:find("event=latency", 1, true) then
			local ev = parse_kv_line(line)
			if ev.event == "latency" and ev.op == out.op then
				if ev.stage == "codex_exec" and not out.codex_exec_ms then
					out.codex_exec_ms = tonumber_or_nil(ev.elapsed_ms)
				end
				if ev.stage == "validate" and not out.validate_ms then
					out.validate_ms = tonumber_or_nil(ev.elapsed_ms)
				end
				if ev.result and out.result == "-" then
					out.result = ev.result
				end
			end
		end

		if out.codex_exec_ms and out.validate_ms then
			break
		end
	end

	local total = 0
	local any = false

	if out.codex_exec_ms then
		total = total + out.codex_exec_ms
		any = true
	end

	if out.validate_ms then
		total = total + out.validate_ms
		any = true
	end

	if any then
		out.total_ms = total
	end

	return out, nil
end

local function fmt_ms(value)
	if not value then
		return "-"
	end
	return string.format("%d ms", value)
end

function M.render_lines()
	local info, err = M.read_latest()
	if not info then
		return {
			"Codex Latency Report",
			"====================",
			"",
			"Error: " .. tostring(err),
		}
	end

	return {
		"Codex Latency Report",
		"====================",
		"",
		"Last operation:   " .. tostring(info.op or "-"),
		"Result:           " .. tostring(info.result or "-"),
		"",
		"Codex execution:  " .. fmt_ms(info.codex_exec_ms),
		"Clang validate:   " .. fmt_ms(info.validate_ms),
		"Total observed:   " .. fmt_ms(info.total_ms),
	}
end

local function open_report_buffer(lines)
	local bufname = "codex://latency"
	local bufnr = vim.fn.bufnr(bufname)

	if bufnr == -1 then
		vim.cmd("botright new")
		bufnr = vim.api.nvim_get_current_buf()
		vim.api.nvim_buf_set_name(bufnr, bufname)
	else
		vim.cmd("botright sbuffer " .. bufnr)
	end

	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
	vim.bo[bufnr].buftype = "nofile"
	vim.bo[bufnr].bufhidden = "wipe"
	vim.bo[bufnr].swapfile = false
	vim.bo[bufnr].filetype = "markdown"

	return bufnr
end

function M.show()
	open_report_buffer(M.render_lines())
end

return M