-- ~/.config/nvim/lua/codex_mode.lua
local M = {}

local state = {
	current = "refactor",
}

local profiles = {
	strict = {
		name = "strict",
		explain_suffix = "\n\nSTRICT MODE:\n- Be extremely precise.\n- Avoid speculation.\n- If unsure, explicitly say so.\n",
		rewrite_suffix = "\n\nSTRICT MODE:\n- No stylistic changes beyond instruction.\n- Preserve structure unless required.\n",
	},

	-- Refactor profile: designed for *selection-only* refactors that still pass whole-buffer clang validation.
	refactor = {
		name = "refactor",
		explain_suffix = "\n\nREFACTOR MODE:\n- Explain refactor tradeoffs briefly.\n- Prefer minimal, safe changes.\n",
		rewrite_suffix = table.concat({
			"",
			"REFACTOR MODE (HARD RULES):",
			"- Output MUST be code only (no commentary).",
			"- Output MUST be ONLY the rewritten selection; do not include surrounding file content.",
			"",
			"- Preserve external interface unless I explicitly ask otherwise.",
			"- Do NOT rename the selected function.",
			"- Do NOT change the selected function signature (name, parameter list, return type).",
			"",
			"- The selection MUST remain EXACTLY ONE function definition.",
			"- Do NOT add any other top-level declarations in the output (no new helper functions, no extra functions, no structs/classes/enums, no templates, no overloads).",
			"- Do NOT create lambdas or local function-objects to replace helpers.",
			"- Do NOT introduce any new symbol that reuses an existing name in the file (no shadowing).",
			"",
			"- If a helper already exists elsewhere in the file that satisfies the goal, you MUST reuse it via a call; never redefine it.",
			"- If asked to extract clamp logic and a clamp helper exists, call it with appropriate bounds rather than creating a new clamp.",
			"",
			"- Prefer internal clarity only: local variable naming, small control-flow cleanup, comments, const correctness (only if interface unchanged).",
			"",
		}, "\n"),
	},

	balanced = {
		name = "balanced",
		explain_suffix = "",
		rewrite_suffix = "",
	},

	fast = {
		name = "fast",
		explain_suffix = "\n\nFAST MODE:\n- Keep output minimal.\n- Skip redundant explanation.\n",
		rewrite_suffix = "\n\nFAST MODE:\n- Minimal formatting changes.\n",
	},
}

function M.get()
	return profiles[state.current]
end

function M.set(name)
	if profiles[name] then
		state.current = name
		return true
	end
	return false
end

function M.current()
	return state.current
end

function M.names()
	local out = {}
	for k, _ in pairs(profiles) do
		table.insert(out, k)
	end
	table.sort(out)
	return out
end

function M.cycle()
	-- Order: balanced -> strict -> refactor -> fast -> balanced
	if state.current == "balanced" then
		state.current = "strict"
	elseif state.current == "strict" then
		state.current = "refactor"
	elseif state.current == "refactor" then
		state.current = "fast"
	else
		state.current = "balanced"
	end
	return state.current
end

return M

