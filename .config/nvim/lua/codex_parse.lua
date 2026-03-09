-- ~/.config/nvim/lua/codex_parse.lua
-- Pure parsing/cleanup helpers for Codex CLI output.
-- No UI, no buffer writes, no notify calls.

local M = {}

-- ------------------------------------------------------------
-- Line utilities
-- ------------------------------------------------------------

function M.normalize_lines(lines)
	local out = {}
	for _, l in ipairs(lines or {}) do
		if l ~= nil then
			out[#out + 1] = (tostring(l):gsub("\r", ""))
		end
	end
	return out
end

function M.trim_blank_edges(lines)
	local out = vim.deepcopy(lines or {})
	local function blank(s)
		return s == nil or tostring(s):match("^%s*$")
	end
	while #out > 0 and blank(out[1]) do
		table.remove(out, 1)
	end
	while #out > 0 and blank(out[#out]) do
		table.remove(out)
	end
	return out
end

local function is_blank(s)
	return s == nil or tostring(s):match("^%s*$")
end

-- ------------------------------------------------------------
-- Codex transcript cleaning
-- ------------------------------------------------------------

-- Keep only the assistant answer portion from Codex CLI output.
-- Primary path: start capturing only after a line that equals "codex".
-- Fallback path: if "codex" marker never appears, drop everything up to
-- (and including) the last "thinking" marker.
function M.clean_codex_output(lines)
	local out = {}
	local capture = false

	for _, line in ipairs(lines or {}) do
		if line == nil then
			goto continue
		end

		line = tostring(line):gsub("\r", "")

		-- Start capturing ONLY after the transcript marker.
		if vim.trim(line) == "codex" then
			capture = true
			goto continue
		end

		if not capture then
			goto continue
		end

		-- Drop common noise
		if line:match("^tokens used") then
			goto continue
		end
		if line:match("^Press ENTER") then
			goto continue
		end
		if line:match("^Skipping markdown%-preview build") then
			goto continue
		end

		-- Drop lines that are just a number (e.g. "2,665")
		if line:match("^%s*%d[%d,]*%s*$") then
			goto continue
		end

		table.insert(out, line)

		::continue::
	end

	if #out == 0 then
		-- Fallback when Codex CLI doesn't print the "codex" transcript marker.
		-- Heuristic: drop everything up to (and including) the last "thinking" marker.
		local raw = M.normalize_lines(lines or {})

		local last_thinking = nil
		for i = 1, #raw do
			if vim.trim(raw[i] or "") == "thinking" then
				last_thinking = i
			end
		end

		local start = (last_thinking and (last_thinking + 1)) or 1
		local sliced = {}
		for i = start, #raw do
			sliced[#sliced + 1] = raw[i]
		end

		out = sliced
	end

	-- Trim leading/trailing empty lines
	while #out > 0 and is_blank(out[1]) do
		table.remove(out, 1)
	end
	while #out > 0 and is_blank(out[#out]) do
		table.remove(out)
	end

	-- De-dupe consecutive identical lines (keeps blank lines)
	local dedup = {}
	local prev = nil
	for _, l in ipairs(out) do
		if l ~= prev then
			table.insert(dedup, l)
		end
		prev = l
	end
	out = dedup

	-- BLOCK DEDUPE: if output is exactly repeated twice, keep only the first half.
	local function strip_trailing_blanks(t)
		local r = vim.deepcopy(t)
		while #r > 0 and is_blank(r[#r]) do
			table.remove(r)
		end
		return r
	end

	local function slice(t, a, b)
		local r = {}
		for i = a, b do
			r[#r + 1] = t[i]
		end
		return r
	end

	local function equal(a, b)
		if #a ~= #b then
			return false
		end
		for i = 1, #a do
			if a[i] ~= b[i] then
				return false
			end
		end
		return true
	end

	local cleaned = strip_trailing_blanks(out)
	local n = #cleaned
	if n >= 6 and (n % 2 == 0) then
		local half = n / 2
		local a = slice(cleaned, 1, half)
		local b = slice(cleaned, half + 1, n)
		if equal(a, b) then
			return a
		end
	end

	return out
end

-- ------------------------------------------------------------
-- Marker extraction helpers
-- ------------------------------------------------------------

function M.extract_between_markers(lines, begin_mark, end_mark)
	local out, on = {}, false
	for _, l in ipairs(lines or {}) do
		local t = vim.trim(tostring(l or ""))
		if t == begin_mark then
			on = true
			goto continue
		end
		if t == end_mark then
			break
		end
		if on then
			table.insert(out, tostring(l))
		end
		::continue::
	end
	return M.trim_blank_edges(out)
end

function M.parse_apply_body(raw_lines)
	-- 1) parse markers from raw first (best chance to see markers)
	local body = M.extract_between_markers(raw_lines, "<<<BEGIN>>>", "<<<END>>>")
	if #body > 0 then
		return body
	end

	-- 2) fallback: try cleaned transcript output in case codex wrapped things oddly
	local cleaned = M.clean_codex_output(raw_lines)
	body = M.extract_between_markers(cleaned, "<<<BEGIN>>>", "<<<END>>>")
	return body
end

-- Prefer cleaned answer (codex section); if that fails, fall back to normalized output.
function M.prefer_clean_answer(lines)
	local raw = M.normalize_lines(lines or {})
	local cleaned = M.clean_codex_output(raw)
	cleaned = M.trim_blank_edges(cleaned)

	if #cleaned > 0 then
		return cleaned
	end

	-- fallback: at least return something readable
	return M.trim_blank_edges(raw)
end

-- ------------------------------------------------------------
-- Output “rule break” heuristics
-- ------------------------------------------------------------

-- Heuristic for when Codex ignores "code only" rules and starts chatting.
function M.looks_like_chatty_output(lines)
	local body = M.trim_blank_edges(lines or {})
	local first = vim.trim(body[1] or "")

	if first == "" then
		return false
	end

	-- Keep these conservative: only obvious chatty openers.
	return first:match("^Happy to help")
		or first:match("^Please paste")
		or first:match("^What text should I")
		or first:match("^Sure")
		or first:match("^I can")
end

-- Heuristic for whole-file rewrites: refuse obvious “meta/prose” responses.
function M.looks_like_file_prose(lines)
	local body = M.trim_blank_edges(lines or {})
	local first = vim.trim(body[1] or "")

	if first == "" then
		return false
	end

	return first:match("^I attempted") or first:match("^Confirm") or first:match("^Proposed change")
end

return M
