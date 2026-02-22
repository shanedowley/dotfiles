local M = {}

local function last_theme_path()
	return vim.fn.stdpath("data") .. "/last-theme.txt"
end

local function load_saved_theme(default_scheme)
	local f = io.open(last_theme_path(), "r")
	if f then
		local s = f:read("*l")
		f:close()
		if s and vim.fn.empty(s) == 0 then
			return s
		end
	end
	return default_scheme
end

local function save_theme(scheme)
	local f = io.open(last_theme_path(), "w")
	if f then
		f:write(scheme)
		f:close()
	end
end

local function lazy_load(id)
	local ok_lazy, lazy = pcall(require, "lazy")
	if not ok_lazy then
		return false, "lazy not available"
	end

	local plugins = require("lazy.core.config").plugins
	if not plugins or not plugins[id] then
		return false, ("Plugin %s not found in Lazy registry"):format(id)
	end

	pcall(function()
		lazy.load({ plugins = { id } })
	end)

	return true
end

local function apply_scheme(entry)
	-- entry = { scheme = "tokyonight-night", id = "tokyonight" }
	if not entry or not entry.scheme or entry.scheme == "" then
		return false, "no scheme"
	end

	if entry.id and entry.id ~= "" then
		local ok, err = lazy_load(entry.id)
		if not ok then
			return false, err
		end
	end

	local ok, err = pcall(vim.cmd.colorscheme, entry.scheme)
	if not ok then
		return false, tostring(err)
	end

	vim.g.active_theme = entry.scheme
	return true
end

function M.setup(list, default_scheme)
	default_scheme = default_scheme or (list[1] and list[1].scheme) or "default"

	-- map scheme -> index
	local idx_by_scheme = {}
	for i, e in ipairs(list) do
		idx_by_scheme[e.scheme] = i
	end

	local current = idx_by_scheme[load_saved_theme(default_scheme)] or 1

	-- apply once at startup
	do
		local ok, err = apply_scheme(list[current])
		if not ok then
			vim.schedule(function()
				vim.notify("Theme apply failed: " .. tostring(err), vim.log.levels.WARN, { title = "theme_cycle" })
			end)
		end
	end

	vim.keymap.set("n", "<leader>ut", function()
		current = (current % #list) + 1
		local entry = list[current]
		local ok, err = apply_scheme(entry)
		if ok then
			save_theme(entry.scheme)
			vim.notify("Theme switched to: " .. entry.scheme, vim.log.levels.INFO, { title = "theme_cycle" })
			pcall(function()
				require("lualine").refresh()
			end)
		else
			vim.notify(
				("Failed theme: %s\n%s"):format(entry.scheme, tostring(err)),
				vim.log.levels.ERROR,
				{ title = "theme_cycle" }
			)
		end
	end, { desc = "Switch color scheme" })
end

return M
