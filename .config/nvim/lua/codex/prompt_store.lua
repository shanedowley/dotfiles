-- ~/.config/nvim/lua/codex/prompt_store.lua
local M = {}

local CONFIG_PROMPT_DIR = vim.fn.expand("~/.config/nvim/codex/prompts")

local DEFAULTS = {
	explain_c = [[
Explain the following snippet step-by-step (C and C++ where relevant).

Rules:
- First, echo the snippet exactly as you received it in a fenced block labeled: ```received ... ```.
- If the snippet appears incomplete/truncated, say so explicitly before analysis.
- Be strictly accurate about the C/C++ standard rules. If unsure, say so.
- Clearly separate: (A) well-defined behavior, (B) unspecified/indeterminate order, (C) implementation-defined behavior, (D) undefined behavior (UB).
- When discussing arithmetic, be precise about: integer promotions, usual arithmetic conversions, and signed/unsigned mixing.
- Do NOT claim that 'float promotes to double' in ordinary expressions in C. (That's only guaranteed for default argument promotions, e.g., varargs.)
- Do NOT say 'snippet is incomplete/truncated'. Treat it as a standalone snippet and state assumptions explicitly (e.g., assume a and b are int unless shown otherwise).
- Separate compile-time ill-formed/constraint violations from runtime UB. Don't label missing includes as runtime UB; say 'diagnostic required' (C) / 'ill-formed' (C++).
- For C++, be precise: <cstdio> + std::printf (don't imply printf is always in the global namespace).
- Only raise format-string UB if you can name the exact mismatch after default argument promotions.
- For sequencing UB, use the canonical language: 'unsequenced modification and value computation/read of the same scalar' (C++) / 'between sequence points, a side effect and an unsequenced read' (C). Don't paraphrase
- For pointer arithmetic, state the valid range (same array object or one-past) and what is UB.
- Keep it concise: maximum 12 bullets. No filler, focused on what applies to THIS snippet.
- Do NOT rewrite the code unless I ask.
]],

	explain_generic = [[
Explain the following {{filetype}} snippet step-by-step.

Rules:
- First, echo the snippet exactly as you received it in a fenced block labeled: ```received ... ```.
- Be strictly accurate about the language semantics and runtime behavior. If unsure, say so explicitly.
- Focus on what THIS snippet does and why (control flow, data flow, key language features used).
- Call out likely errors, edge cases, and surprising behavior, but don’t invent context not present.
- Keep it concise: maximum 12 bullets.
- Do NOT rewrite the code unless I ask.
]],

	apply = [[
You are rewriting ONLY the selected text provided below.

Return ONLY the replacement text BETWEEN these exact markers, and NOTHING else:
<<<BEGIN>>>
(replacement lines)
<<<END>>>

ABSOLUTE RULES:
- Output must contain BOTH markers, always.
- No explanation, no questions, no advice.
- No markdown fences/backticks in your output.
- Preserve indentation and line breaks.
- Output must be valid code for the same language as the input.

If you cannot comply, your entire output MUST be exactly:
<<<BEGIN>>>
ERROR
<<<END>>>

Instruction:
{{instruction}}

Selected text:
<<<SELECTED>>>
{{selected_text}}
<<<END_SELECTED>>>
]],

	raw_rewrite = [[
You will be given a code snippet below.
Apply my instruction to that snippet.

ABSOLUTE OUTPUT RULES:
- Output ONLY the rewritten code. No prose. No explanations. No questions.
- No markdown fences/backticks.
- Preserve indentation.
{{line_count_rule}}

Instruction:
{{instruction}}
]],

	unified_diff = [[
Generate a unified diff that applies my instruction to the provided snippet.

ABSOLUTE OUTPUT RULES:
- Output ONLY a unified diff. No prose. No explanations.
- No markdown fences/backticks.
- Use these exact filenames in the headers:
  --- a/selection
  +++ b/selection
- Include at least one hunk header starting with @@.

Instruction:
{{instruction}}
]],

	entire_file_rewrite = [[
You will be given an entire file below.
Apply my instruction to it.

ABSOLUTE OUTPUT RULES:
- Output ONLY the full rewritten file contents. No prose. No patch format. No approvals talk.
- No markdown fences/backticks.
- Preserve content you are not changing.

Instruction:
{{instruction}}
]],
}

local function read_file(path)
	local fd = io.open(path, "r")
	if not fd then
		return nil
	end
	local content = fd:read("*a")
	fd:close()
	return content
end

local function trim_trailing_newlines(s)
	return (s or ""):gsub("\n+$", "")
end

function M.dir()
	return CONFIG_PROMPT_DIR
end

function M.path_for(name)
	return CONFIG_PROMPT_DIR .. "/" .. name .. ".md"
end

function M.get(name)
	local path = M.path_for(name)
	local content = read_file(path)

	if content and content ~= "" then
		return trim_trailing_newlines(content), path, false
	end

	return DEFAULTS[name], path, true
end

function M.version()
	local parts = {}

	for name, _ in pairs(DEFAULTS) do
		local content, _, _ = M.get(name)
		parts[#parts + 1] = name .. ":" .. tostring(#(content or ""))
	end

	table.sort(parts)
	return "store:" .. table.concat(parts, "|")
end

function M.defaults()
	return vim.deepcopy(DEFAULTS)
end

return M
