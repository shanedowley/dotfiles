-- ~/.config/nvim/lua/codex_cli.lua
local M = {}

local parse = require("codex_parse")
local prompt = require("codex_prompt")
local mode = require("codex_mode")
local codex_log = require("codex_log")
local recovery = require("codex_recovery")
local guard = require("codex_guard")
local memory = require("codex_memory")
local selection = require("codex.selection")
local ts = require("codex.treesitter")
local clang = require("codex.clang")
local runner = require("codex.runner")
local preview = require("codex.preview")
local state = require("codex.state")

-- -------------------------------------------------------------------
-- Generic helpers
-- -------------------------------------------------------------------

local function current_file(bufnr)
	bufnr = bufnr or 0
	return vim.api.nvim_buf_get_name(bufnr)
end

local function set_state_running(op_name, bufnr, message)
	state.set("running", {
		op = op_name,
		mode = mode.current(),
		file = current_file(bufnr),
		message = message or "Codex request started",
	})
end

local function set_state_preview(op_name, bufnr, message)
	state.set("preview", {
		op = op_name,
		mode = mode.current(),
		file = current_file(bufnr),
		message = message or "Diff preview open",
	})
end

local function set_state_validating(op_name, bufnr, message)
	state.set("validating", {
		op = op_name,
		mode = mode.current(),
		file = current_file(bufnr),
		message = message or "Running clang validation",
	})
end

local function set_state_applied(op_name, bufnr, message)
	state.set("applied", {
		op = op_name,
		mode = mode.current(),
		file = current_file(bufnr),
		message = message or "Changes applied successfully",
	})
end

local function set_state_failed(op_name, bufnr, message)
	state.set("failed", {
		op = op_name,
		mode = mode.current(),
		file = current_file(bufnr),
		message = message or "Codex operation failed",
	})
end

local function set_state_idle(op_name, bufnr, message)
	state.set("idle", {
		op = op_name,
		mode = mode.current(),
		file = current_file(bufnr),
		message = message or "Codex operation complete",
	})
end

local function system_run(argv)
	if not vim.system then
		return { code = 127, stdout = "", stderr = "vim.system not available", signal = nil }
	end

	local res = vim.system(argv, { text = true }):wait()
	return {
		code = res.code or 1,
		stdout = res.stdout or "",
		stderr = res.stderr or "",
		signal = res.signal,
	}
end

local function split_nonempty_lines(s)
	local out = {}
	for line in (s or ""):gmatch("([^\n]*)\n?") do
		if line ~= "" then
			table.insert(out, line)
		end
	end
	return out
end

local function open_scratch(lines, filetype, title)
	title = title or "Codex Output"

	local bufname = "codex://" .. title
	local bufnr = vim.fn.bufnr(bufname)

	if bufnr == -1 then
		vim.cmd("botright new")
		bufnr = vim.api.nvim_get_current_buf()
		vim.api.nvim_buf_set_name(bufnr, bufname)
	else
		vim.cmd("botright sbuffer " .. bufnr)
	end

	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines or {})
	vim.bo[bufnr].buftype = "nofile"
	vim.bo[bufnr].bufhidden = "wipe"
	vim.bo[bufnr].swapfile = false

	if filetype then
		vim.bo[bufnr].filetype = filetype
	end

	return bufnr
end

local function prompt_user(opts, cb)
	vim.ui.input({ prompt = opts.prompt, default = opts.default }, function(answer)
		if answer and answer ~= "" then
			cb(answer)
		end
	end)
end

local function sanitize_prompt_for_log(text)
	text = tostring(text or "")
	text = text:gsub("\n", " ")
	text = text:gsub("%s+", " ")
	text = vim.trim(text)

	if #text > 500 then
		text = text:sub(1, 500) .. "..."
	end

	return text
end

local function remember_and_log_op(op_name, user_prompt)
	local file = current_file(0)
	local current_mode = mode.current()
	local prompt_version = prompt.version and prompt.version() or "unknown"
	local cleaned_prompt = sanitize_prompt_for_log(user_prompt)

	memory.save_last_op({
		op = op_name,
		prompt = user_prompt,
		mode = current_mode,
		prompt_version = prompt_version,
		timestamp = os.time(),
	})

	set_state_running(op_name, 0, "Codex request started")

	codex_log.write("prompt", {
		mode = current_mode,
		file = file,
		prompt_version = prompt_version,
		op = op_name,
		text = cleaned_prompt,
	})
end

local function write_tempfile(lines, suffix)
	local path = vim.fn.tempname() .. (suffix or "")
	vim.fn.writefile(lines or {}, path)
	return path
end

local function build_local_unified_diff(original_lines, candidate_lines, ft)
	local suffix = ".txt"
	ft = ft or ""

	if ft == "c" then
		suffix = ".c"
	elseif ft == "cpp" or ft == "cxx" or ft == "cc" or ft == "objc" or ft == "objcpp" then
		suffix = ".cpp"
	end

	local old_path = write_tempfile(original_lines or {}, suffix)
	local new_path = write_tempfile(candidate_lines or {}, suffix)

	if vim.fn.executable("diff") ~= 1 then
		return nil, { "Local diff preview unavailable: `diff` not found in PATH." }
	end

	local res = system_run({ "diff", "-u", old_path, new_path })

	if res.code ~= 0 and res.code ~= 1 then
		local err = split_nonempty_lines(res.stderr)
		if #err == 0 then
			err = split_nonempty_lines(res.stdout)
		end
		if #err == 0 then
			err = { "Failed to build local unified diff." }
		end
		return nil, err
	end

	local diff_lines = split_nonempty_lines(res.stdout)

	if res.code == 0 or #diff_lines == 0 then
		return {}, nil
	end

	return diff_lines, nil
end

-- -------------------------------------------------------------------
-- Validation helpers
-- -------------------------------------------------------------------

local function validate_apply_body(raw, body, want_lines, title_prefix, op_name)
	title_prefix = title_prefix or "Apply"

	if #body == 0 then
		codex_log.write("error", {
			mode = mode.current(),
			file = current_file(0),
			reason = "apply_block_missing",
		})

		set_state_failed(op_name, 0, title_prefix .. ": no marked replacement block found")

		recovery.show_failure({
			reason = title_prefix .. ": no marked replacement block found",
			title = "Codex " .. title_prefix .. " (unparsed)",
			lines = raw,
		})
		return nil
	end

	if #body == 1 and vim.trim(body[1]) == "ERROR" then
		codex_log.write("error", {
			mode = mode.current(),
			file = current_file(0),
			reason = "codex_returned_error",
		})

		set_state_failed(op_name, 0, title_prefix .. ": Codex returned ERROR")

		recovery.show_failure({
			reason = title_prefix .. ": Codex returned ERROR",
			title = "Codex " .. title_prefix .. " (ERROR)",
			lines = raw,
		})
		return nil
	end

	if want_lines and #body ~= want_lines then
		codex_log.write("error", {
			mode = mode.current(),
			file = current_file(0),
			reason = "wrong_line_count",
			result = string.format("got_%d_want_%d", #body, want_lines),
		})

		set_state_failed(
			op_name,
			0,
			string.format("%s: wrong line count (got %d, want %d)", title_prefix, #body, want_lines)
		)

		recovery.show_failure({
			reason = string.format("%s: wrong line count (got %d, want %d)", title_prefix, #body, want_lines),
			title = "Codex " .. title_prefix .. " (wrong line count)",
			lines = raw,
		})
		return nil
	end

	return body
end

local function validate_rewrite_common(original_text, body, want_lines, opts)
	opts = opts or {}
	local op_name = opts.op_name

	if parse.looks_like_chatty_output(body) then
		codex_log.write("error", {
			mode = mode.current(),
			file = current_file(0),
			reason = "rule_break_output",
		})
		set_state_failed(op_name, 0, "Codex violated output rules")
		open_scratch(body, "text", "Codex Output (rule break)")
		vim.notify("Codex violated output rules; not applying", vim.log.levels.WARN, { title = "Codex" })
		return nil
	end

	body = selection.trim_blank_edges(body)

	local bad, why = guard.too_large_rewrite(body, want_lines)
	if bad then
		codex_log.write("error", {
			mode = mode.current(),
			file = current_file(0),
			reason = why or "invalid_rewrite",
		})
		set_state_failed(op_name, 0, "Codex output rejected: " .. (why or "invalid"))
		open_scratch(body, "text", "Codex Output (rejected)")
		vim.notify("Codex output rejected: " .. (why or "invalid"), vim.log.levels.WARN, { title = "Codex" })
		return nil
	end

	if opts.check_preprocessor then
		local bad_pp, why_pp = guard.rejects_preprocessor_injection(body)
		if bad_pp then
			codex_log.write("error", {
				mode = mode.current(),
				file = current_file(0),
				reason = "preprocessor_injection_rejected",
			})
			set_state_failed(op_name, 0, "Codex output rejected by preprocessor guard")
			open_scratch(why_pp, "text", "Codex Output (guard rejected)")
			vim.notify("Codex output rejected by guard", vim.log.levels.WARN, { title = "Codex" })
			return nil
		end
	end

	if opts.check_refactor and mode.current() == "refactor" then
		local bad2, why_lines = guard.violates_refactor_single_function(original_text, body)
		if bad2 then
			codex_log.write("error", {
				mode = mode.current(),
				file = current_file(0),
				reason = "refactor_guard_rejected",
			})
			set_state_failed(op_name, 0, "Codex output rejected by refactor guard")
			open_scratch(why_lines, "text", "Codex Output (rejected)")
			vim.notify("Codex output rejected by refactor guard", vim.log.levels.WARN, { title = "Codex" })
			return nil
		end
	end

	return body
end

local function clang_validate_or_reject(bufnr, ft, start_line, end_line, body, user_prompt, title, op_name)
	if not clang.is_cc_ft(ft) then
		return true
	end

	set_state_validating(op_name, bufnr, "Running clang validation")

	local ok, clang_lines, tmppath, meta = clang.preflight_range_replace(bufnr, ft, start_line, end_line, body)

	codex_log.write("validate", {
		mode = mode.current(),
		file = current_file(bufnr),
		result = ok and "PASS" or "FAIL",
		check = "clang",
	})

	codex_log.write("latency", {
		mode = mode.current(),
		file = current_file(bufnr),
		stage = "clang_preflight",
		elapsed_ms = meta.elapsed_ms or -1,
		result = ok and "PASS" or "FAIL",
	})

	if ok then
		return true
	end

	codex_log.write("error", {
		mode = mode.current(),
		file = current_file(bufnr),
		reason = "clang_rejected",
	})

	set_state_failed(op_name, bufnr, "clang validation rejected candidate")

	clang.open_rejection_scratch({
		title = title or "Codex Rejected (clang)",
		ft = ft,
		user_instruction = user_prompt,
		start_line = start_line,
		end_line = end_line,
		candidate_lines = body,
		clang_lines = clang_lines,
		temp_path = tmppath,
		meta = meta,
	})

	vim.notify("clang rejected rewrite; not applied", vim.log.levels.ERROR, { title = "Codex" })
	return false
end

local function apply_lines_and_log(bufnr, start_line, end_line, body, op_name)
	vim.api.nvim_buf_set_lines(bufnr, start_line - 1, end_line, false, body)

	codex_log.write("apply", {
		mode = mode.current(),
		file = current_file(bufnr),
		result = "SUCCESS",
		range = string.format("%d-%d", start_line, end_line),
	})

	set_state_applied(op_name, bufnr, "Changes applied successfully")
end

-- -------------------------------------------------------------------
-- Safe preview flow helper
-- -------------------------------------------------------------------

local function safe_preview_flow(opts)
	local target_bufnr = opts.target_bufnr or vim.api.nvim_get_current_buf()
	local ft = opts.ft or (vim.bo[target_bufnr].filetype or "")
	local original_lines = opts.original_lines or {}
	local original_text = opts.original_text or table.concat(original_lines, "\n")
	local want_lines = opts.want_lines
	local prompt_label = opts.prompt_label or "instruction"
	local op_name = opts.op_name
	local preview_title = opts.preview_title or "Codex Safe Diff Preview"
	local clang_title = opts.clang_title or "Codex Rejected (clang)"
	local raw_title_prefix = opts.raw_title_prefix or "Apply"

	prompt_user({ prompt = "Codex [" .. mode.current() .. "] " .. prompt_label .. ": " }, function(user_prompt)
		remember_and_log_op(op_name, user_prompt)

		local p = prompt.build_apply(user_prompt, original_text)

		runner.run({
			op = op_name,
			filetype = ft,
			prompt = p,
			spinner_message = "Codex [" .. mode.current() .. "] working…",

			on_success = function(result)
				local raw = parse.normalize_lines(result.output)

				local body = parse.parse_apply_body(raw)
				body = selection.collapse_if_doubled(body, want_lines)
				body = validate_apply_body(raw, body, nil, raw_title_prefix, op_name)
				if not body then
					return
				end

				body = validate_rewrite_common(original_text, body, want_lines or #original_lines, {
					op_name = op_name,
					check_preprocessor = false,
					check_refactor = opts.check_refactor,
				})
				if not body then
					return
				end

				local diff_lines, diff_err = build_local_unified_diff(original_lines, body, ft)
				if not diff_lines then
					set_state_failed(op_name, target_bufnr, "Failed to build diff preview")
					open_scratch(diff_err or { "Failed to build diff preview." }, "text", "Codex Diff Preview (error)")
					vim.notify("Failed to build local diff preview", vim.log.levels.ERROR, { title = "Codex" })
					return
				end

				if #diff_lines == 0 then
					set_state_idle(op_name, target_bufnr, "No changes produced")
					vim.notify("No changes produced", vim.log.levels.INFO, { title = "Codex" })
					return
				end

				set_state_preview(op_name, target_bufnr, "Diff preview open")

				preview.open_diff(diff_lines, {
					title = preview_title,
					on_confirm = function()
						local ok = clang_validate_or_reject(
							target_bufnr,
							ft,
							opts.start_line,
							opts.end_line,
							body,
							user_prompt,
							clang_title,
							op_name
						)

						if not ok then
							return false
						end

						apply_lines_and_log(target_bufnr, opts.start_line, opts.end_line, body, op_name)
						vim.notify("Preview confirmed and applied", vim.log.levels.INFO, { title = "Codex" })
						return true
					end,
				})
			end,

			on_failure = function(result)
				set_state_failed(op_name, target_bufnr, "Codex execution failed")
				local raw = parse.normalize_lines(result.output)
				open_scratch(raw, "text", "Codex Safe Apply (failed)")
			end,
		})
	end)
end

-- -------------------------------------------------------------------
-- Public API
-- -------------------------------------------------------------------

function M.replace_current_function()
	local ft = vim.bo.filetype or "text"
	local start_line, end_line = ts.get_current_function_range_cc()

	if not start_line or not end_line then
		vim.notify("No enclosing function found at cursor", vim.log.levels.WARN, { title = "Codex" })
		return
	end

	local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
	local text = table.concat(lines, "\n")

	M.replace_range(text, start_line, end_line, ft)
end

function M.explain_current_line()
	local line = vim.fn.getline(".")
	local ft = vim.bo.filetype or ""
	local default_prompt = prompt.build_explain(ft)

	prompt_user({ prompt = "Codex explain: ", default = default_prompt }, function(user_prompt)
		remember_and_log_op("explain_current_line", user_prompt)

		runner.run_embedded(line, user_prompt, {
			op = "explain_current_line",
			filetype = ft,
			spinner_message = "Codex [" .. mode.current() .. "] working…",
			on_success = function(result)
				set_state_idle("explain_current_line", 0, "Explanation opened in scratch buffer")
				open_scratch(parse.clean_codex_output(result.output), "markdown", "Explain Line")
			end,
			on_failure = function(result)
				set_state_failed("explain_current_line", 0, "Codex execution failed")
				if #result.stderr > 0 then
					open_scratch(result.stderr, "text", "Codex STDERR")
				end
			end,
		})
	end)
end

function M.explain_text(text)
	local ft = vim.bo.filetype or ""
	local default_prompt = prompt.build_explain(ft)

	prompt_user({ prompt = "Codex explain: ", default = default_prompt }, function(user_prompt)
		set_state_running("explain_text", 0, "Codex request started")

		runner.run_embedded(text, user_prompt, {
			op = "explain_text",
			filetype = ft,
			spinner_message = "Codex [" .. mode.current() .. "] working…",
			on_success = function(result)
				set_state_idle("explain_text", 0, "Explanation opened in scratch buffer")
				open_scratch(parse.clean_codex_output(result.output), "markdown", "Explain Selection")
			end,
			on_failure = function(result)
				set_state_failed("explain_text", 0, "Codex execution failed")
				if #result.stderr > 0 then
					open_scratch(result.stderr, "text", "Codex STDERR")
				end
			end,
		})
	end)
end

function M.explain_selection()
	local text = select(1, selection.collect_selection())
	local ft = vim.bo.filetype or ""
	local default_prompt = prompt.build_explain(ft)

	prompt_user({ prompt = "Codex explain: ", default = default_prompt }, function(user_prompt)
		remember_and_log_op("explain_selection", user_prompt)

		runner.run_embedded(text, user_prompt, {
			op = "explain_selection",
			filetype = ft,
			spinner_message = "Codex [" .. mode.current() .. "] working…",
			on_success = function(result)
				set_state_idle("explain_selection", 0, "Explanation opened in scratch buffer")
				open_scratch(parse.clean_codex_output(result.output), "markdown", "Explain Selection")
			end,
			on_failure = function(result)
				set_state_failed("explain_selection", 0, "Codex execution failed")
				if #result.stderr > 0 then
					open_scratch(result.stderr, "text", "Codex STDERR")
				end
			end,
		})
	end)
end

function M.apply_inline_current_line()
	local line = vim.fn.getline(".")
	local lnum = vim.fn.line(".")
	local ft = vim.bo.filetype or ""
	local want_lines = 1
	local op_name = "apply_inline_current_line"

	prompt_user({ prompt = "Codex [" .. mode.current() .. "] instruction: " }, function(user_prompt)
		remember_and_log_op(op_name, user_prompt)

		local p = prompt.build_apply(user_prompt, line)

		runner.run({
			op = op_name,
			filetype = ft,
			prompt = p,
			spinner_message = "Codex [" .. mode.current() .. "] working…",

			on_success = function(result)
				local raw = parse.normalize_lines(result.output)
				local body = parse.parse_apply_body(raw)
				body = validate_apply_body(raw, body, want_lines, "Apply", op_name)
				if not body then
					return
				end

				local ok = clang_validate_or_reject(0, ft, lnum, lnum, body, user_prompt, "Codex Rejected (clang)", op_name)
				if not ok then
					return
				end

				apply_lines_and_log(0, lnum, lnum, body, op_name)
			end,

			on_failure = function(result)
				set_state_failed(op_name, 0, "Codex execution failed")
				local raw = parse.normalize_lines(result.output)
				open_scratch(raw, "text", "Codex Apply (failed)")
			end,
		})
	end)
end

function M.replace_range(text, start_line, end_line, ft)
	if not text or vim.trim(text) == "" then
		vim.notify("No selection captured", vim.log.levels.WARN, { title = "Codex" })
		return
	end

	ft = ft or (vim.bo.filetype or "text")
	local want_lines = selection.lines_count(text)
	local op_name = "replace_range"

	prompt_user({ prompt = "Codex [" .. mode.current() .. "] instruction: " }, function(user_prompt)
		remember_and_log_op(op_name, user_prompt)

		local p = prompt.build_raw_rewrite(user_prompt, ft, want_lines)

		runner.run_embedded(text, p, {
			op = op_name,
			filetype = ft,
			spinner_message = "Codex [" .. mode.current() .. "] working…",

			on_success = function(result)
				local body = parse.prefer_clean_answer(result.output)
				body = selection.collapse_if_doubled(body, want_lines)

				body = validate_rewrite_common(text, body, want_lines, {
					op_name = op_name,
					check_preprocessor = true,
					check_refactor = true,
				})
				if not body then
					return
				end

				local ok =
					clang_validate_or_reject(0, ft, start_line, end_line, body, user_prompt, "Codex Rejected (clang)", op_name)
				if not ok then
					return
				end

				apply_lines_and_log(0, start_line, end_line, body, op_name)
			end,

			on_failure = function(result)
				set_state_failed(op_name, 0, "Codex execution failed")
				if #result.stderr > 0 then
					open_scratch(result.stderr, "text", "Codex STDERR")
				end
			end,
		})
	end)
end

function M.replace_selection()
	local text, start_line, end_line = selection.collect_selection()
	if not text or vim.trim(text) == "" then
		vim.notify("No selection captured", vim.log.levels.WARN, { title = "Codex" })
		return
	end

	M.replace_range(text, start_line, end_line, vim.bo.filetype or "text")
end

function M.open_output_scratch()
	local text = select(1, selection.collect_selection())
	if not text or vim.trim(text) == "" then
		vim.notify("No selection captured", vim.log.levels.WARN, { title = "Codex" })
		return
	end

	local ft = vim.bo.filetype or "text"
	local op_name = "open_output_scratch"

	prompt_user({ prompt = "Codex [" .. mode.current() .. "] instruction: " }, function(user_prompt)
		set_state_running(op_name, 0, "Codex request started")
		local p = prompt.build_raw_rewrite(user_prompt, ft, nil)

		runner.run_embedded(text, p, {
			op = op_name,
			filetype = ft,
			spinner_message = "Codex [" .. mode.current() .. "] working…",

			on_success = function(result)
				local body = parse.prefer_clean_answer(result.output)
				body = selection.collapse_if_doubled(body, nil)
				set_state_idle(op_name, 0, "Output opened in scratch buffer")
				open_scratch(body, nil, "Codex Output")
			end,

			on_failure = function(result)
				set_state_failed(op_name, 0, "Codex execution failed")
				if #result.stderr > 0 then
					open_scratch(result.stderr, "text", "Codex STDERR")
				end
			end,
		})
	end)
end

function M.save_output_to_file_text(text)
	if not text or vim.trim(text) == "" then
		vim.notify("No selection captured", vim.log.levels.WARN, { title = "Codex" })
		return
	end

	local ft = vim.bo.filetype or "text"
	local op_name = "save_output_to_file_text"

	prompt_user({ prompt = "Codex [" .. mode.current() .. "] instruction: " }, function(user_prompt)
		prompt_user({ prompt = "Save output as: " }, function(filename)
			set_state_running(op_name, 0, "Codex request started")
			local p = prompt.build_raw_rewrite(user_prompt, ft, nil)

			runner.run_embedded(text, p, {
				op = op_name,
				filetype = ft,
				spinner_message = "Codex [" .. mode.current() .. "] working…",

				on_success = function(result)
					local to_write = parse.prefer_clean_answer(result.output)
					to_write = selection.collapse_if_doubled(to_write, nil)

					if parse.looks_like_chatty_output(to_write) then
						set_state_failed(op_name, 0, "Codex violated output rules; not writing file")
						open_scratch(to_write, "text", "Codex Output (rule break)")
						vim.notify(
							"Codex violated output rules; not writing file",
							vim.log.levels.WARN,
							{ title = "Codex" }
						)
						return
					end

					vim.cmd("edit " .. vim.fn.fnameescape(filename))
					vim.api.nvim_buf_set_lines(0, 0, -1, false, to_write)
					vim.cmd("write")
					set_state_idle(op_name, 0, "Codex output written to file")
					vim.notify("Codex output written to " .. filename, vim.log.levels.INFO, { title = "Codex" })
				end,

				on_failure = function(result)
					set_state_failed(op_name, 0, "Codex execution failed")
					if #result.stderr > 0 then
						open_scratch(result.stderr, "text", "Codex STDERR")
					end
				end,
			})
		end)
	end)
end

function M.apply_inline()
	local text, start_line, end_line = selection.collect_selection()
	if not text or vim.trim(text) == "" then
		vim.notify("No selection captured", vim.log.levels.WARN, { title = "Codex" })
		return
	end

	local ft = vim.bo.filetype or ""
	local want_lines = selection.lines_count(text)
	local op_name = "apply_inline"

	prompt_user({ prompt = "Codex [" .. mode.current() .. "] instruction: " }, function(user_prompt)
		remember_and_log_op(op_name, user_prompt)

		local p = prompt.build_apply(user_prompt, text)

		runner.run({
			op = op_name,
			filetype = ft,
			prompt = p,
			spinner_message = "Codex [" .. mode.current() .. "] working…",

			on_success = function(result)
				local raw = parse.normalize_lines(result.output)
				local body = parse.parse_apply_body(raw)
				body = validate_apply_body(raw, body, want_lines, "Apply", op_name)
				if not body then
					return
				end

				local ok =
					clang_validate_or_reject(0, ft, start_line, end_line, body, user_prompt, "Codex Rejected (clang)", op_name)
				if not ok then
					return
				end

				apply_lines_and_log(0, start_line, end_line, body, op_name)
			end,

			on_failure = function(result)
				set_state_failed(op_name, 0, "Codex execution failed")
				local raw = parse.normalize_lines(result.output)
				open_scratch(raw, "text", "Codex Apply (failed)")
			end,
		})
	end)
end

function M.preview_diff_current_line()
	local line = vim.fn.getline(".")
	local lnum = vim.fn.line(".")
	local ft = vim.bo.filetype or ""

	if not line or vim.trim(line) == "" then
		vim.notify("No line captured", vim.log.levels.WARN, { title = "Codex" })
		return
	end

	safe_preview_flow({
		op_name = "preview_diff_current_line",
		prompt_label = "instruction (diff)",
		raw_title_prefix = "Apply",
		preview_title = "Diff Preview",
		clang_title = "Codex Rejected (clang)",
		target_bufnr = vim.api.nvim_get_current_buf(),
		ft = ft,
		start_line = lnum,
		end_line = lnum,
		want_lines = 1,
		original_lines = { line },
		original_text = line,
		check_refactor = false,
	})
end

function M.preview_diff()
	local text, start_line, end_line = selection.collect_selection()
	local ft = vim.bo.filetype or ""

	if not text or vim.trim(text) == "" then
		vim.notify("No selection captured", vim.log.levels.WARN, { title = "Codex" })
		return
	end

	safe_preview_flow({
		op_name = "preview_diff",
		prompt_label = "instruction (diff)",
		raw_title_prefix = "Apply",
		preview_title = "Diff Preview",
		clang_title = "Codex Rejected (clang)",
		target_bufnr = vim.api.nvim_get_current_buf(),
		ft = ft,
		start_line = start_line,
		end_line = end_line,
		want_lines = selection.lines_count(text),
		original_lines = vim.fn.getline(start_line, end_line),
		original_text = text,
		check_refactor = false,
	})
end

function M.run_current_line()
	local line = vim.fn.getline(".")
	local lnum = vim.fn.line(".")
	local ft = vim.bo.filetype or "text"
	local op_name = "run_current_line"

	prompt_user({ prompt = "Codex [" .. mode.current() .. "] instruction: " }, function(user_prompt)
		remember_and_log_op(op_name, user_prompt)

		local p = prompt.build_raw_rewrite(user_prompt, ft, 1)

		runner.run_embedded(line, p, {
			op = op_name,
			filetype = ft,
			spinner_message = "Codex [" .. mode.current() .. "] working…",

			on_success = function(result)
				local body = parse.prefer_clean_answer(result.output)
				body = selection.collapse_if_doubled(body, 1)

				body = validate_rewrite_common(line, body, 1, {
					op_name = op_name,
					check_preprocessor = true,
					check_refactor = false,
				})
				if not body then
					return
				end

				local single_line = { body[1] or line }

				local ok =
					clang_validate_or_reject(0, ft, lnum, lnum, single_line, user_prompt, "Codex Rejected (clang)", op_name)
				if not ok then
					return
				end

				apply_lines_and_log(0, lnum, lnum, single_line, op_name)
			end,

			on_failure = function(result)
				set_state_failed(op_name, 0, "Codex execution failed")
				if #result.stderr > 0 then
					open_scratch(result.stderr, "text", "Codex STDERR")
				end
			end,
		})
	end)
end

function M.run_entire_file()
	local buf = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	local text = table.concat(buf, "\n")
	local ft = vim.bo.filetype or "text"
	local op_name = "run_entire_file"

	prompt_user({ prompt = "Codex [" .. mode.current() .. "] instruction: " }, function(user_prompt)
		remember_and_log_op(op_name, user_prompt)

		local p = prompt.build_entire_file_rewrite(user_prompt)

		runner.run_embedded(text, p, {
			op = op_name,
			filetype = ft,
			spinner_message = "Codex [" .. mode.current() .. "] working…",

			on_success = function(result)
				local body = parse.prefer_clean_answer(result.output)
				body = selection.collapse_if_doubled(body, nil)

				if parse.looks_like_file_prose(body) or parse.looks_like_chatty_output(body) then
					set_state_failed(op_name, 0, "Codex returned non-file output; not overwriting buffer")
					open_scratch(body, "text", "Codex File Output (refused overwrite)")
					vim.notify(
						"Codex returned non-file output; not overwriting buffer",
						vim.log.levels.WARN,
						{ title = "Codex" }
					)
					return
				end

				local ok =
					clang_validate_or_reject(0, ft, 1, #buf, body, user_prompt, "Codex Rejected (clang)", op_name)
				if not ok then
					return
				end

				apply_lines_and_log(0, 1, #buf, body, op_name)
			end,

			on_failure = function(result)
				set_state_failed(op_name, 0, "Codex execution failed")
				if #result.stderr > 0 then
					open_scratch(result.stderr, "text", "Codex STDERR")
				end
			end,
		})
	end)
end

function M.patch_buffer()
	local filename = vim.fn.expand("%:p")
	prompt_user({ prompt = "Codex patch: " }, function(p_text)
		set_state_idle("patch_buffer", 0, "Opened Codex diff terminal")
		local cmd = string.format("codex --diff %q %q", p_text, filename)
		vim.cmd("botright split | term " .. cmd)
	end)
end

function M.scratchpad_prompt(default_prompt)
	local op_name = "scratchpad_prompt"

	prompt_user({ prompt = "Codex scratch: ", default = default_prompt or "" }, function(p_text)
		local text = vim.api.nvim_buf_get_lines(0, 0, -1, false)
		local buftext = table.concat(text, "\n")
		local ft = vim.bo.filetype or ""

		set_state_running(op_name, 0, "Codex request started")

		runner.run_embedded(buftext, p_text, {
			op = op_name,
			filetype = ft,
			spinner_message = "Codex [" .. mode.current() .. "] working…",

			on_success = function(result)
				set_state_idle(op_name, 0, "Scratchpad output opened")
				open_scratch(parse.clean_codex_output(result.output), "markdown")
			end,

			on_failure = function(result)
				set_state_failed(op_name, 0, "Codex execution failed")
				if #result.stderr > 0 then
					open_scratch(result.stderr, "text", "Codex STDERR")
				end
			end,
		})
	end)
end

function M.safe_preview_confirm_apply_selection()
	local text, start_line, end_line = selection.collect_selection()
	if not text or vim.trim(text) == "" then
		vim.notify("No selection captured", vim.log.levels.WARN, { title = "Codex" })
		return
	end

	safe_preview_flow({
		op_name = "safe_preview_confirm_apply_selection",
		prompt_label = "instruction",
		raw_title_prefix = "Apply",
		preview_title = "Codex Safe Diff Preview",
		clang_title = "Codex Rejected (clang)",
		target_bufnr = vim.api.nvim_get_current_buf(),
		ft = vim.bo.filetype or "",
		start_line = start_line,
		end_line = end_line,
		want_lines = selection.lines_count(text),
		original_lines = vim.fn.getline(start_line, end_line),
		original_text = text,
		check_refactor = false,
	})
end

function M.safe_preview_confirm_apply_current_function()
	local ft = vim.bo.filetype or ""
	local start_line, end_line = ts.get_current_function_range_cc()

	if not start_line or not end_line then
		vim.notify("No enclosing function found at cursor", vim.log.levels.WARN, { title = "Codex" })
		return
	end

	local target_bufnr = vim.api.nvim_get_current_buf()
	local original_lines = vim.api.nvim_buf_get_lines(target_bufnr, start_line - 1, end_line, false)
	local original_text = table.concat(original_lines, "\n")

	safe_preview_flow({
		op_name = "safe_preview_confirm_apply_current_function",
		prompt_label = "refactor",
		raw_title_prefix = "Refactor",
		preview_title = "Codex Function Refactor Preview",
		clang_title = "Codex Refactor Rejected (clang)",
		target_bufnr = target_bufnr,
		ft = ft,
		start_line = start_line,
		end_line = end_line,
		want_lines = nil,
		original_lines = original_lines,
		original_text = original_text,
		check_refactor = true,
	})
end

function M.health_check()
	require("codex.health").show()
end

function M.show_state()
	require("codex.state").show()
end

pcall(vim.api.nvim_del_user_command, "CodexHealth")
vim.api.nvim_create_user_command("CodexHealth", function()
	require("codex_cli").health_check()
end, {})

pcall(vim.api.nvim_del_user_command, "CodexState")
vim.api.nvim_create_user_command("CodexState", function()
	require("codex_cli").show_state()
end, {})

return M