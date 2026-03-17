local M = {}

local function log_path()
	return vim.fn.stdpath("state") .. "/codex.log"
end

local function timestamp()
	return os.date("%Y-%m-%d %H:%M:%S")
end

local function serialize(data)
	if not data then
		return ""
	end

	local parts = {}
	for k, v in pairs(data) do
		if v ~= nil then
			local value = tostring(v):gsub("\n", "\\n")
			table.insert(parts, string.format("%s=%s", k, value))
		end
	end

	table.sort(parts)
	return table.concat(parts, " ")
end

function M.path()
	return log_path()
end

function M.write(event, data)
	local line = string.format("[%s] event=%s", timestamp(), event)

	local extra = serialize(data)
	if extra ~= "" then
		line = line .. " " .. extra
	end

	line = line .. "\n"

	local ok, err = pcall(function()
		local f = assert(io.open(log_path(), "a"))
		f:write(line)
		f:close()
	end)

	if not ok then
		vim.schedule(function()
			vim.notify("Codex log write failed: " .. tostring(err), vim.log.levels.WARN)
		end)
	end
end

function M.clear()
	local ok, err = pcall(function()
		local f = assert(io.open(log_path(), "w"))
		f:write("")
		f:close()
	end)

	if not ok then
		vim.schedule(function()
			vim.notify("Codex log clear failed: " .. tostring(err), vim.log.levels.WARN)
		end)
	end
end

function M.open_log()
	local path = vim.fn.stdpath("state") .. "/codex.log"

	-- open log in split
	vim.cmd("botright split " .. path)

	-- jump to end
	vim.cmd("normal! G")

	-- mark buffer read-only
	vim.bo.readonly = true
	vim.bo.modifiable = false
end

vim.api.nvim_create_user_command("CodexLog", function()
	require("codex_log").open_log()
end, {})

return M
