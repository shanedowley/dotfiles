-- ~/.config/nvim/lua/codex_guard.lua

local M = {}

local function extract_first_function_name(text)
	for _, l in ipairs(vim.split(text or "", "\n", { plain = true })) do
		local line = vim.trim(l or "")
		if line ~= "" then
			if line:match("^%s*//") or line:match("^%s*/%*") or line:match("^%s*#") then
				goto continue
			end

			local _, name = line:match("^%s*(.-)%s+([%w_:~]+)%s*%b()%s*$")
			if name then
				return name
			end

			local _, name2 = line:match("^%s*(.-)%s+([%w_:~]+)%s*%b()%s*%{")
			if name2 then
				return name2
			end
		end

		::continue::
	end
	return nil
end

local function count_function_defs_and_names(lines)
	local defs = {}

	for i, l in ipairs(lines or {}) do
		local line = (l or "")

		if
			line:match("^%s*if%s*%(")
			or line:match("^%s*else%s+if%s*%(")
			or line:match("^%s*else%s*$")
			or line:match("^%s*for%s*%(")
			or line:match("^%s*while%s*%(")
			or line:match("^%s*switch%s*%(")
			or line:match("^%s*return%s")
		then
			goto continue
		end

		local _, name = line:match("^%s*(.-)%s+([%w_:~]+)%s*%b()%s*%{")
		if name then
			table.insert(defs, { line = vim.trim(line), name = name, idx = i })
			goto continue
		end

		local _, name2 = line:match("^%s*(.-)%s+([%w_:~]+)%s*%b()%s*$")
		if name2 then
			for j = i + 1, math.min(i + 6, #lines) do
				local nxt = lines[j] or ""
				if vim.trim(nxt) == "" then
					-- skip blanks
				elseif nxt:match("^%s*%{") then
					table.insert(defs, { line = vim.trim(line), name = name2, idx = i })
					break
				else
					break
				end
			end
		end

		::continue::
	end

	return defs
end

function M.violates_refactor_single_function(original_selection_text, candidate_lines)
	local orig_name = extract_first_function_name(original_selection_text)
	if not orig_name then
		return false, nil
	end

	local defs = count_function_defs_and_names(candidate_lines)

	if #defs == 0 then
		return true,
			{
				"Refactor guard: rejected candidate output.",
				"Reason: no function definition detected in candidate output.",
			}
	end

	if #defs > 1 then
		local out = {
			"Refactor guard: rejected candidate output.",
			"Reason: candidate contains multiple function definitions (injection / helper creation).",
			"Detected function defs:",
		}
		for _, d in ipairs(defs) do
			table.insert(out, string.format("%d | %s", d.idx, d.line))
		end
		return true, out
	end

	if defs[1].name ~= orig_name then
		return true,
			{
				"Refactor guard: rejected candidate output.",
				("Reason: function name changed or new helper introduced (%s -> %s)."):format(orig_name, defs[1].name),
				("Candidate def: %d | %s"):format(defs[1].idx, defs[1].line),
			}
	end

	return false, nil
end

function M.too_large_rewrite(body, want_lines)
	local n = #body
	if n == 0 then
		return true, "empty output"
	end

	local max_abs = 300
	if n > max_abs then
		return true, string.format("output too large (%d lines)", n)
	end

	if want_lines and want_lines > 0 then
		local max_mul = 4
		if n > (want_lines * max_mul) then
			return true, string.format("output grew too much (%d → %d lines)", want_lines, n)
		end
	end

	return false, nil
end

function M.contains_preprocessor_injection(lines)
	local hits = {}

	for i, l in ipairs(lines or {}) do
		local line = vim.trim(l or "")
		if line:match("^#%s*include%s+") or line:match("^#%s*define%s+") or line:match("^#%s*pragma%s+") then
			table.insert(hits, string.format("%d | %s", i, line))
		end
	end

	return #hits > 0, hits
end

function M.rejects_preprocessor_injection(lines)
	local bad, hits = M.contains_preprocessor_injection(lines)
	if not bad then
		return false, nil
	end

	local out = {
		"Guard rejected candidate output.",
		"Reason: preprocessor or include injection detected.",
		"Detected lines:",
	}
	vim.list_extend(out, hits)
	return true, out
end

return M
