-- PDF -> Text
vim.api.nvim_create_user_command("PDFtoText", function(opts)
	local input = opts.args
	if input == "" then
		print("Usage: :PDFtoText <file.pdf>")
		return
	end
	local infile = vim.fn.fnamemodify(input, ":p")
	if vim.fn.filereadable(infile) == 0 then
		vim.notify("PDFtoText: file not found -> " .. infile, vim.log.levels.WARN)
		return
	end
	local tmpfile = vim.fn.tempname() .. ".txt"
	local cmd = { "pdftotext", infile, tmpfile }
	local output = vim.fn.system(cmd)
	if vim.v.shell_error ~= 0 then
		vim.notify("❌  PDFtoText: conversion failed -> " .. output, vim.log.levels.ERROR)
		return
	end

	-- Success message
	vim.notify("✅  PDFtoText: converted -> " .. tmpfile, vim.log.levels.INFO)
	vim.cmd("edit! " .. tmpfile)
end, {
	nargs = 1,
	complete = "file",
	desc = "Convert PDF to plain text and open in Neovim",
})

-- PDF -> Markdown
vim.api.nvim_create_user_command("PDFtoMd", function(opts)
	local input = opts.args
	if input == "" then
		print("Usage: :PDFtoMd <file.pdf>")
		return
	end
	local infile = vim.fn.fnamemodify(input, ":p")
	if vim.fn.filereadable(infile) == 0 then
		vim.notify("PDFtoMd: file not found -> " .. infile, vim.log.levels.WARN)
		return
	end
	local tmpfile = vim.fn.tempname() .. ".md"
	local cmd = string.format(
		"pdftotext -layout %s - | pandoc -f markdown -t markdown -o %s",
		vim.fn.shellescape(infile),
		vim.fn.shellescape(tmpfile)
	)
	local output = vim.fn.system(cmd)
	if vim.v.shell_error ~= 0 then
		vim.notify("❌  PDFtoMd: conversion failed -> " .. output, vim.log.levels.ERROR)
		return
	end

	-- Success message
	vim.notify("✅  PDFtoMd: converted -> " .. tmpfile, vim.log.levels.INFO)
	vim.cmd("edit! " .. tmpfile)
end, {
	nargs = 1,
	complete = "file",
	desc = "Convert PDF to Markdown and open in Neovim",
})

-- RmApp wrapper
vim.api.nvim_create_user_command("RmApp", function()
	vim.cmd("terminal rm-app")
end, {
	desc = "Safely uninstall a macOS app with logs",
})

-- Keymap for RmApp
vim.keymap.set("n", "<leader>ua", ":RmApp<CR>", { desc = "Uninstall macOS app" })
