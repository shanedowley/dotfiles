local M = {}

local enabled = true

local ROOT_MARKERS = {
	".git",
	"compile_commands.json",
	"Cargo.toml",
	"go.mod",
	"build.zig",
	"package.json",
	"pyproject.toml",
	"Makefile",
	"CMakeLists.txt",
}

function M.enabled()
	return enabled
end

function M.toggle()
	enabled = not enabled
	return enabled
end

local function current_path(bufnr)
	bufnr = bufnr or 0
	local name = vim.api.nvim_buf_get_name(bufnr)
	if name == "" then
		return nil
	end
	return vim.fn.fnamemodify(name, ":p")
end

local function parent_dir(path)
	return vim.fn.fnamemodify(path, ":h")
end

local function marker_type(name)
	if name == ".git" then
		return "directory"
	end
	return "file"
end

local function find_root(start_path)
	if not start_path or start_path == "" then
		return nil, {}
	end

	local start_dir = parent_dir(start_path)
	local best_root = nil
	local best_markers = nil

	for _, marker in ipairs(ROOT_MARKERS) do
		local found = vim.fs.find(marker, {
			upward = true,
			path = start_dir,
			limit = 1,
			type = marker_type(marker),
		})

		if found and #found > 0 then
			local root = parent_dir(found[1])

			if not best_root or #root > #best_root then
				best_root = root
				best_markers = { marker }
			elseif root == best_root then
				best_markers = best_markers or {}
				table.insert(best_markers, marker)
			end
		end
	end

	if not best_root then
		return nil, {}
	end

	table.sort(best_markers)
	return best_root, best_markers
end

function M.collect(bufnr)
	bufnr = bufnr or 0

	local path = current_path(bufnr)
	local ft = vim.bo[bufnr].filetype or ""
	local root, markers = find_root(path)

	local rel = nil
	if root and path then
		local prefix = root .. "/"
		if path:sub(1, #prefix) == prefix then
			rel = path:sub(#prefix + 1)
		else
			rel = vim.fn.fnamemodify(path, ":t")
		end
	end

	return {
		enabled = enabled,
		file = path,
		filetype = ft,
		project_root = root,
		relative_file = rel,
		markers = markers or {},
	}
end

function M.render_block(bufnr)
	if not enabled then
		return ""
	end

	local info = M.collect(bufnr)

	local lines = {
		"READ-ONLY PROJECT CONTEXT (metadata only):",
		"- project_root: " .. tostring(info.project_root or "unknown"),
		"- file: " .. tostring(info.relative_file or info.file or "unknown"),
		"- filetype: " .. tostring(info.filetype or "unknown"),
	}

	if info.markers and #info.markers > 0 then
		lines[#lines + 1] = "- markers: " .. table.concat(info.markers, ", ")
	else
		lines[#lines + 1] = "- markers: none"
	end

	lines[#lines + 1] = ""
	lines[#lines + 1] = "CONTEXT USAGE RULES:"
	lines[#lines + 1] = "- Use this only as background orientation."
	lines[#lines + 1] = "- Do NOT mention this context in your answer."
	lines[#lines + 1] = "- Do NOT inspect files, run commands, or describe tool usage."
	lines[#lines + 1] = "- Do NOT ask to open or search the project."
	lines[#lines + 1] = "- Still obey all output rules exactly."

	return table.concat(lines, "\n")
end

return M
