-- ~/.config/nvim/lua/codex_status.lua

local M = {}
local mode = require("codex_mode")

local mode_labels = {
	balanced = "Balanced",
	fast = "Fast",
	strict = "Strict",
	refactor = "Refactor",
}

local mode_hex = {
	balanced = "#7aa2f7",
	fast = "#9ece6a",
	strict = "#f7768e",
	refactor = "#bb9af7",
}

function M.status()
	local m = mode.current() or "unknown"
	return mode_labels[m] or "Unknown"
end

function M.color()
	local m = mode.current() or "unknown"
	return mode_hex[m] or "#7aa2f7"
end

return M

