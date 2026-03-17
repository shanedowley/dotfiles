local M = {}

local last_op = nil

function M.save_last_op(op)
	last_op = vim.deepcopy(op)
end

function M.get_last_op()
	if not last_op then
		return nil
	end
	return vim.deepcopy(last_op)
end

function M.clear_last_op()
	last_op = nil
end

return M
