-- ~/.config/nvim/lua/codex_prompt.lua

local M = {}

local PROMPT_VERSION = "v1"

-- -------------------------------------------------------------------
-- Mode helper
-- -------------------------------------------------------------------

local mode = require("codex_mode")

function M.version()
	return PROMPT_VERSION
end

function M.header_lines()
	local current_mode = mode.current() or "unknown"
	return {
		("PROMPT_VERSION: %s"):format(PROMPT_VERSION),
		("PROMPT_MODE: %s"):format(current_mode),
		"",
	}
end

-- -------------------------------------------------------------------
-- Language helpers (prompt/fence awareness)
-- -------------------------------------------------------------------

local C_FAMILY = {
	c = true,
	cpp = true,
	objc = true,
	objcpp = true,
	cuda = true,
}

function M.is_c_family(ft)
	return C_FAMILY[ft or ""] == true
end

-- Map Neovim filetypes to reasonable fenced-block language labels.
local FENCE_FT_MAP = {
	[""] = "text",
	text = "text",
	typescriptreact = "tsx",
	javascriptreact = "jsx",
	sh = "bash",
	zsh = "bash",
}

function M.fence_lang(ft)
	ft = ft or ""
	if M.is_c_family(ft) then
		-- Prefer cpp fence for C++-ish variants; otherwise c.
		if ft == "cpp" or ft == "objcpp" or ft == "cuda" then
			return "cpp"
		end
		return "c"
	end
	return FENCE_FT_MAP[ft] or ft
end

-- -------------------------------------------------------------------
-- Prompt builders
-- -------------------------------------------------------------------

function M.build_explain(ft)
	ft = ft or ""

	-- Preserve high-rigor C-family explain prompt.
	if M.is_c_family(ft) then
		local parts = vim.list_extend(M.header_lines(), {
			"Explain the following snippet step-by-step (C and C++ where relevant).",
			"",
			"Rules:",
			"- First, echo the snippet exactly as you received it in a fenced block labeled: ```received ... ```.",
			"- If the snippet appears incomplete/truncated, say so explicitly before analysis.",
			"- Be strictly accurate about the C/C++ standard rules. If unsure, say so.",
			"- Clearly separate: (A) well-defined behavior, (B) unspecified/indeterminate order, (C) implementation-defined behavior, (D) undefined behavior (UB).",
			"- When discussing arithmetic, be precise about: integer promotions, usual arithmetic conversions, and signed/unsigned mixing.",
			"- Do NOT claim that 'float promotes to double' in ordinary expressions in C. (That's only guaranteed for default argument promotions, e.g., varargs.)",
			"- Do NOT say 'snippet is incomplete/truncated'. Treat it as a standalone snippet and state assumptions explicitly (e.g., assume a and b are int unless shown otherwise).",
			"- Separate compile-time ill-formed/constraint violations from runtime UB. Don't label missing includes as runtime UB; say 'diagnostic required' (C) / 'ill-formed' (C++).",
			"- For C++, be precise: <cstdio> + std::printf (don't imply printf is always in the global namespace).",
			"- Only raise format-string UB if you can name the exact mismatch after default argument promotions.",
			"For sequencing UB, use the canonical language: 'unsequenced modification and value computation/read of the same scalar' (C++) / 'between sequence points, a side effect and an unsequenced read' (C). Don't paraphrase",
			"- For pointer arithmetic, state the valid range (same array object or one-past) and what is UB.",
			"- Keep it concise: maximum 12 bullets. No filler, focused on what applies to THIS snippet.",
			"- Do NOT rewrite the code unless I ask.",
		})

		local base = table.concat(parts, "\n")
		local profile = mode.get()
		return base .. (profile.explain_suffix or "")
	end

	-- Generic explain prompt for non C-family.
	local parts = vim.list_extend(M.header_lines(), {
		string.format("Explain the following %s snippet step-by-step.", (ft ~= "" and ft) or "code"),
		"",
		"Rules:",
		"- First, echo the snippet exactly as you received it in a fenced block labeled: ```received ... ```.",
		"- Be strictly accurate about the language semantics and runtime behavior. If unsure, say so explicitly.",
		"- Focus on what THIS snippet does and why (control flow, data flow, key language features used).",
		"- Call out likely errors, edge cases, and surprising behavior, but don’t invent context not present.",
		"- Keep it concise: maximum 12 bullets.",
		"- Do NOT rewrite the code unless I ask.",
	})

	local base = table.concat(parts, "\n")
	local profile = mode.get()
	return base .. (profile.explain_suffix or "")
end

function M.build_apply(user_instruction, selected_text)
	return table.concat(
		vim.list_extend(M.header_lines(), {
			"You are rewriting ONLY the selected text provided below.",
			"",
			"Return ONLY the replacement text BETWEEN these exact markers, and NOTHING else:",
			"<<<BEGIN>>>",
			"(replacement lines)",
			"<<<END>>>",
			"",
			"ABSOLUTE RULES:",
			"- Output must contain BOTH markers, always.",
			"- No explanation, no questions, no advice.",
			"- No markdown fences/backticks in your output.",
			"- Preserve indentation and line breaks.",
			"- Output must be valid code for the same language as the input.",
			"",
			"If you cannot comply, your entire output MUST be exactly:",
			"<<<BEGIN>>>",
			"ERROR",
			"<<<END>>>",
			"",
			"Instruction:",
			user_instruction,
			"",
			"Selected text:",
			"<<<SELECTED>>>",
			selected_text,
			"<<<END_SELECTED>>>",
		}),
		"\n"
	)
end

function M.build_raw_rewrite(user_instruction, ft, line_count)
	local lc = line_count
	local rules = vim.list_extend(M.header_lines(), {
		"You will be given a code snippet below.",
		"Apply my instruction to that snippet.",
		"",
		"ABSOLUTE OUTPUT RULES:",
		"- Output ONLY the rewritten code. No prose. No explanations. No questions.",
		"- No markdown fences/backticks.",
		"- Preserve indentation.",
	})

	if lc then
		table.insert(rules, string.format("- Output must be exactly %d line(s).", lc))
	end

	local base = table.concat(
		vim.list_extend(rules, {
			"",
			"Instruction:",
			user_instruction,
		}),
		"\n"
	)

	local profile = mode.get()
	return base .. (profile.rewrite_suffix or "")
end

function M.build_unified_diff(instruction)
	return table.concat(
		vim.list_extend(M.header_lines(), {
			"Generate a unified diff that applies my instruction to the provided snippet.",
			"",
			"ABSOLUTE OUTPUT RULES:",
			"- Output ONLY a unified diff. No prose. No explanations.",
			"- No markdown fences/backticks.",
			"- Use these exact filenames in the headers:",
			"  --- a/selection",
			"  +++ b/selection",
			"- Include at least one hunk header starting with @@.",
			"",
			"Instruction:",
			instruction,
		}),
		"\n"
	)
end

function M.build_entire_file_rewrite(user_instruction)
	return table.concat(
		vim.list_extend(M.header_lines(), {
			"You will be given an entire file below.",
			"Apply my instruction to it.",
			"",
			"ABSOLUTE OUTPUT RULES:",
			"- Output ONLY the full rewritten file contents. No prose. No patch format. No approvals talk.",
			"- No markdown fences/backticks.",
			"- Preserve content you are not changing.",
			"",
			"Instruction:",
			user_instruction,
		}),
		"\n"
	)
end

return M
