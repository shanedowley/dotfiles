-- ~/.config/nvim/lua/codex/treesitter.lua

local M = {}

-- -------------------------------------------------------------------
-- Tree-sitter helpers: get current function range (C/C++)
-- -------------------------------------------------------------------

local function ts_get_node_at_cursor()
	if not vim.treesitter or not vim.treesitter.get_parser then
		return nil
	end

	local bufnr = 0
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	row = row - 1

	local ok_parser, parser = pcall(vim.treesitter.get_parser, bufnr)
	if not ok_parser or not parser then
		return nil
	end

	local trees = parser:parse()
	local tree = trees and trees[1]
	if not tree then
		return nil
	end

	local root = tree:root()
	if not root then
		return nil
	end

	local node = root:named_descendant_for_range(row, col, row, col)
	return node
end

local function ts_find_enclosing_function_node(node)
	local function_types = {
		function_definition = true,
		method_definition = true,
	}

	while node do
		local t = node:type()
		if function_types[t] then
			return node
		end
		node = node:parent()
	end

	return nil
end

local function ts_node_to_line_range(node)
	local sr, _, er, ec = node:range()

	local start_line = sr + 1

	local end_line
	if ec == 0 and er > sr then
		end_line = er
	else
		end_line = er + 1
	end

	return start_line, end_line
end

function M.get_current_function_range_cc()
	local ft = vim.bo.filetype or ""

	if ft ~= "c" and ft ~= "cpp" and ft ~= "objc" and ft ~= "objcpp" then
		return nil, nil
	end

	local node = ts_get_node_at_cursor()
	if not node then
		return nil, nil
	end

	local fn_node = ts_find_enclosing_function_node(node)
	if not fn_node then
		return nil, nil
	end

	return ts_node_to_line_range(fn_node)
end

return M
