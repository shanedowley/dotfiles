-- ~/.config/nvim/lua/_scratch/neotest_probe.lua
local nio = require("nio")

nio.run(function()
	local adapter = require("neotest-gtest").setup({})
	local p = vim.fn.expand("%:p")

	print("probe p=" .. p)

	-- IMPORTANT: try calling as a method (:) not a field (.).
	local ok1, res1 = pcall(function()
		return adapter:discover_positions(p)
	end)
	print("call adapter:discover_positions(p)  ok=" .. tostring(ok1) .. "  type=" .. type(res1))
	if not ok1 then
		print("err1=" .. tostring(res1))
	end
end)
