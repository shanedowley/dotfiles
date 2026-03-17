local M = {}

function M.collect_selection()
	local bufnr = 0

	local vpos = vim.fn.getpos("v")
	local cpos = vim.fn.getpos(".")

	local start_line = vpos[2]
	local start_col = vpos[3]
	local end_line = cpos[2]
	local end_col = cpos[3]

	if start_line > 0 and end_line > 0 then
		if start_line > end_line or (start_line == end_line and start_col > end_col) then
			start_line, end_line = end_line, start_line
			start_col, end_col = end_col, start_col
		end

		local lines = vim.api.nvim_buf_get_text(bufnr, start_line - 1, start_col - 1, end_line - 1, end_col, {})
		return table.concat(lines, "\n"), start_line, end_line
	end

	local start_pos = vim.fn.getpos("'<")
	local end_pos = vim.fn.getpos("'>")

	start_line = start_pos[2]
	end_line = end_pos[2]

	if start_line > 0 and end_line > 0 then
		if start_line > end_line then
			start_line, end_line = end_line, start_line
		end

		local lines = vim.fn.getline(start_line, end_line)
		return table.concat(lines, "\n"), start_line, end_line
	end

	return nil, nil, nil
end

function M.lines_count(s)
	if not s or s == "" then
		return 0
	end
	local _, n = s:gsub("\n", "\n")
	return n + 1
end

function M.collapse_if_doubled(body, want_lines)
	if type(body) ~= "table" then
		return body
	end

	local n = #body
	if n == 0 then
		return body
	end

	if want_lines == 1 and n == 2 and body[1] == body[2] then
		return { body[1] }
	end

	if want_lines and n == (2 * want_lines) and (n % 2 == 0) then
		local half = n / 2
		for i = 1, half do
			if body[i] ~= body[i + half] then
				return body
			end
		end
		local out = {}
		for i = 1, half do
			out[#out + 1] = body[i]
		end
		return out
	end

	if (not want_lines) and (n % 2 == 0) and n >= 2 then
		local half = n / 2
		for i = 1, half do
			if body[i] ~= body[i + half] then
				return body
			end
		end
		local out = {}
		for i = 1, half do
			out[#out + 1] = body[i]
		end
		return out
	end

	return body
end

function M.trim_blank_edges(lines)
	local first = 1
	local last = #lines

	while first <= last and vim.trim(lines[first] or "") == "" do
		first = first + 1
	end

	while last >= first and vim.trim(lines[last] or "") == "" do
		last = last - 1
	end

	if first > last then
		return {}
	end

	return vim.list_slice(lines, first, last)
end

return M
