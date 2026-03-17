local M = {}

local function expand(path)
	return vim.fn.expand(path)
end

local function path_exists(path)
	return vim.uv.fs_stat(path) ~= nil
end

local function is_readable(path)
	return vim.fn.filereadable(path) == 1
end

local function is_dir(path)
	local stat = vim.uv.fs_stat(path)
	return stat and stat.type == "directory" or false
end

local function add_result(results, name, status, detail)
	results[#results + 1] = {
		name = name,
		status = status,
		detail = detail or "",
	}
end

local function overall_status(results)
	local has_warn = false

	for _, item in ipairs(results) do
		if item.status == "FAIL" then
			return "FAIL"
		end
		if item.status == "WARN" then
			has_warn = true
		end
	end

	if has_warn then
		return "WARN"
	end

	return "PASS"
end

local function count_statuses(results)
	local counts = {
		PASS = 0,
		WARN = 0,
		FAIL = 0,
	}

	for _, item in ipairs(results) do
		if counts[item.status] ~= nil then
			counts[item.status] = counts[item.status] + 1
		end
	end

	return counts
end

local function check_executable(results, exe, required)
	if vim.fn.executable(exe) == 1 then
		add_result(results, "executable: " .. exe, "PASS", "found in PATH")
	else
		add_result(results, "executable: " .. exe, required and "FAIL" or "WARN", "not found in PATH")
	end
end

local function check_module(results, modname, required)
	local ok, loaded = pcall(require, modname)
	if ok and loaded then
		add_result(results, "module: " .. modname, "PASS", "loaded successfully")
	else
		add_result(results, "module: " .. modname, required and "FAIL" or "WARN", "failed to load")
	end
end

local function check_prompt_files(results)
	local prompt_dir = expand(vim.fn.stdpath("config") .. "/codex/prompts")

	if is_dir(prompt_dir) then
		add_result(results, "prompt dir", "PASS", prompt_dir)
	else
		add_result(results, "prompt dir", "WARN", "missing: " .. prompt_dir)
	end

	local required_files = {
		"raw_rewrite.md",
		"apply.md",
	}

	for _, filename in ipairs(required_files) do
		local path = prompt_dir .. "/" .. filename
		if is_readable(path) then
			add_result(results, "prompt file: " .. filename, "PASS", "readable")
		else
			add_result(results, "prompt file: " .. filename, "WARN", "missing/unreadable; fallback should apply")
		end
	end

	local explain_candidates = {
		"explain.md",
		"explain_c.md",
	}

	local found = nil
	for _, filename in ipairs(explain_candidates) do
		local path = prompt_dir .. "/" .. filename
		if is_readable(path) then
			found = filename
			break
		end
	end

	if found then
		add_result(results, "prompt file: explain", "PASS", "using " .. found)
	else
		add_result(
			results,
			"prompt file: explain",
			"WARN",
			"missing/unreadable; checked explain.md and explain_c.md; fallback should apply"
		)
	end
end

local function check_prompt_resolution(results)
	local ok, prompt_mod = pcall(require, "codex_prompt")
	if not ok or not prompt_mod then
		add_result(results, "prompt builders", "FAIL", "codex_prompt unavailable")
		return
	end

	local function check_builder(name, fn)
		local ok_call, value = pcall(fn)
		if ok_call and type(value) == "string" and value ~= "" then
			add_result(results, "prompt build: " .. name, "PASS", "builder returned text")
		elseif not ok_call then
			add_result(results, "prompt build: " .. name, "WARN", "builder raised an error")
		else
			add_result(results, "prompt build: " .. name, "WARN", "builder returned empty/unusable text")
		end
	end

	check_builder("raw_rewrite", function()
		return prompt_mod.build_raw_rewrite("test instruction", "c", 1)
	end)

	check_builder("apply", function()
		return prompt_mod.build_apply("test instruction", "int x = 1;")
	end)

	check_builder("explain", function()
		return prompt_mod.build_explain("c")
	end)
end

local function ensure_parent_dir(path)
	local dir = vim.fn.fnamemodify(path, ":h")

	if path_exists(dir) then
		return true, dir
	end

	local ok = vim.fn.mkdir(dir, "p")
	if ok == 1 or path_exists(dir) then
		return true, dir
	end

	return false, dir
end

local function check_log_path(results)
	local log_path = expand(vim.fn.stdpath("state") .. "/codex.log")
	local ok_dir, dir = ensure_parent_dir(log_path)

	if not ok_dir then
		add_result(results, "log dir", "WARN", "could not create: " .. dir)
		add_result(results, "log file", "WARN", "directory unavailable: " .. log_path)
		return
	end

	add_result(results, "log dir", "PASS", dir)

	local fd = vim.uv.fs_open(log_path, "a", 420) -- 0644
	if not fd then
		add_result(results, "log file", "WARN", "not writable: " .. log_path)
		return
	end

	vim.uv.fs_close(fd)
	add_result(results, "log file", "PASS", log_path)
end

function M.run_checks()
	local results = {}

	-- Hard dependencies
	check_executable(results, "codex", true)
	check_executable(results, "clang", true)

	-- Core modules
	check_module(results, "codex_cli", true)
	check_module(results, "codex.runner", true)
	check_module(results, "codex.preview", true)
	check_module(results, "codex.prompt_store", true)
	check_module(results, "codex_guard", true)
	check_module(results, "codex.clang", true)
	check_module(results, "codex_log", true)
	check_module(results, "codex_prompt", true)

	-- Prompt system
	check_prompt_files(results)
	check_prompt_resolution(results)

	-- Observability path
	check_log_path(results)

	return results
end

function M.summary_status(results)
	return overall_status(results)
end

local function render_report(results)
	local counts = count_statuses(results)
	local overall = overall_status(results)

	local lines = {
		"Codex Health Check",
		"==================",
		"",
		"Overall: " .. overall,
		string.format("PASS: %d   WARN: %d   FAIL: %d", counts.PASS, counts.WARN, counts.FAIL),
		"",
	}

	for _, item in ipairs(results) do
		lines[#lines + 1] = string.format("[%s] %s", item.status, item.name)
		if item.detail and item.detail ~= "" then
			lines[#lines + 1] = "  " .. item.detail
		end
	end

	return lines
end

local function open_report_buffer(lines)
	local buf = vim.api.nvim_create_buf(false, true)
	if not buf then
		vim.notify("Codex health: failed to create report buffer", vim.log.levels.ERROR)
		return
	end

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].swapfile = false
	vim.bo[buf].filetype = "markdown"

	vim.cmd("botright new")
	vim.api.nvim_win_set_buf(0, buf)
	vim.api.nvim_buf_set_name(buf, "codex://health")
end

function M.show()
	local results = M.run_checks()
	local overall = overall_status(results)
	local counts = count_statuses(results)

	local level = vim.log.levels.INFO
	if overall == "WARN" then
		level = vim.log.levels.WARN
	elseif overall == "FAIL" then
		level = vim.log.levels.ERROR
	end

	local summary =
		string.format("Codex health: %s (%d pass, %d warn, %d fail)", overall, counts.PASS, counts.WARN, counts.FAIL)

	vim.notify(summary, level, { title = "Codex" })
	open_report_buffer(render_report(results))

	return results
end

return M
