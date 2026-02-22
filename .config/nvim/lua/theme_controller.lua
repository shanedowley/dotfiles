-- ~/.config/nvim/lua/theme_controller.lua
local M = {}

local function last_theme_path()
	return vim.fn.stdpath("data") .. "/last-theme.txt"
end

local function load_saved_theme(default)
	local file = io.open(last_theme_path(), "r")
	if file then
		local name = file:read("*l")
		file:close()
		if name and vim.fn.empty(name) == 0 then
			return name
		end
	end
	return default
end

local function save_theme(name)
	local file = io.open(last_theme_path(), "w")
	if file then
		file:write(name)
		file:close()
	end
end

function M.setup(theme_list, default_theme)
	default_theme = default_theme or "django-smooth"

	-- name -> lazy id
	local theme_id = {}
	local theme_names = {}
	for _, entry in ipairs(theme_list) do
		theme_id[entry.name] = entry.id
		table.insert(theme_names, entry.name)
	end

	local function load_theme_plugin(name)
		local id = theme_id[name]
		if not id then
			return
		end
		-- Don't overthink registry keys; just ask Lazy to load by id.
		pcall(function()
			require("lazy").load({ plugins = { id } })
		end)
	end

	local function apply_theme(name)
		if not name or name == "" then
			return false
		end

		-- try to load the theme plugin first
		load_theme_plugin(name)

		-- now apply the colorscheme (LOUD on failure)
		local ok, err = pcall(vim.cmd.colorscheme, name)
		if not ok then
			vim.notify(
				("colorscheme %q failed:\n%s"):format(name, tostring(err)),
				vim.log.levels.ERROR,
				{ title = "theme_controller" }
			)
			return false
		end

		vim.g.active_theme = name
		vim.notify(("colorscheme set to %q"):format(name), vim.log.levels.INFO, { title = "theme_controller" })
		return true
	end

	-- Apply saved theme at startup (fallback to default)
	local saved = load_saved_theme(default_theme)
	if not apply_theme(saved) then
		apply_theme(default_theme)
	end

	-- Set up theme cycling keymap
	local current_index = 1
	for i, n in ipairs(theme_names) do
		if n == (vim.g.active_theme or saved) then
			current_index = i
			break
		end
	end

	vim.keymap.set("n", "<leader>ut", function()
		current_index = current_index % #theme_names + 1
		local name = theme_names[current_index]
		if apply_theme(name) then
			save_theme(name)
			vim.notify("Theme switched to: " .. name, vim.log.levels.INFO)
			pcall(function()
				require("lualine").refresh()
			end)
		else
			vim.notify("Failed to load theme " .. name, vim.log.levels.WARN)
		end
	end, { desc = "Switch color scheme" })
end

return M
