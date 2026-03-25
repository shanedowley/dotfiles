-- ~/.config/nvim/lua/codex_prompt.lua

local M = {}

local PROMPT_VERSION = "v2"

local mode = require("codex_mode")
local store = require("codex.prompt_store")
local context = require("codex.context")

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
		if ft == "cpp" or ft == "objcpp" or ft == "cuda" then
			return "cpp"
		end
		return "c"
	end
	return FENCE_FT_MAP[ft] or ft
end

local function substitute(template, vars)
	local out = template or ""
	for k, v in pairs(vars or {}) do
		out = out:gsub("{{" .. k .. "}}", tostring(v or ""))
	end
	return out
end

local function with_header(body)
	return table.concat(vim.list_extend(M.header_lines(), { body }), "\n")
end

local function maybe_with_context(body)
	local ctx = context.render_block(0)
	if not ctx or ctx == "" then
		return body
	end
	return ctx .. "\n\n" .. body
end

function M.build_explain(ft)
	ft = ft or ""

	if M.is_c_family(ft) then
		local template = store.get("explain_c")
		local base = with_header(template)
		local profile = mode.get()
		return base .. (profile.explain_suffix or "")
	end

	local template = store.get("explain_generic")
	local label = (ft ~= "" and ft) or "code"
	local rendered = substitute(template, {
		filetype = label,
	})
	local base = with_header(rendered)
	local profile = mode.get()
	return base .. (profile.explain_suffix or "")
end

function M.build_apply(user_instruction, selected_text)
	local template = store.get("apply")
	local rendered = substitute(template, {
		instruction = user_instruction,
		selected_text = selected_text,
	})
	return with_header(maybe_with_context(rendered))
end

function M.build_raw_rewrite(user_instruction, ft, line_count)
	local line_count_rule = ""
	if line_count then
		line_count_rule = string.format("- Output must be exactly %d line(s).", line_count)
	end

	local template = store.get("raw_rewrite")
	local rendered = substitute(template, {
		instruction = user_instruction,
		filetype = ft or "",
		line_count_rule = line_count_rule,
	})

	local base = with_header(maybe_with_context(rendered))
	local profile = mode.get()
	return base .. (profile.rewrite_suffix or "")
end

function M.build_unified_diff(instruction)
	local template = store.get("unified_diff")
	return with_header(substitute(template, {
		instruction = instruction,
	}))
end

function M.build_entire_file_rewrite(user_instruction)
	local template = store.get("entire_file_rewrite")
	local rendered = substitute(template, {
		instruction = user_instruction,
	})
	return with_header(maybe_with_context(rendered))
end

return M
