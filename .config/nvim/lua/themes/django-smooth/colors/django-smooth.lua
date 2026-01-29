-- django-smooth colorscheme for Neovim
-- inspired by iTerm2 "Django Smooth"
local lush = require("lush")
local hsl = lush.hsl

return lush(function()
	return {
		Normal({ fg = hsl("#e0d7c3"), bg = hsl("#1e1e1d") }),
		Comment({ fg = hsl("#7f7f7f"), gui = "italic" }),
		Constant({ fg = hsl("#a3d8d8") }),
		String({ fg = hsl("#b3c174") }),
		Character({ fg = hsl("#c5b56a") }),
		Number({ fg = hsl("#c9976b") }),
		Boolean({ fg = hsl("#b4a0e5") }),
		Identifier({ fg = hsl("#d1b48c") }),
		Function({ fg = hsl("#9bd6a1") }),
		Statement({ fg = hsl("#89c5c0"), gui = "bold" }),
		Keyword({ fg = hsl("#a3c4e1"), gui = "bold" }),
		Operator({ fg = hsl("#b4a48a") }),
		PreProc({ fg = hsl("#b8c7a1") }),
		Type({ fg = hsl("#a6cf96") }),
		Special({ fg = hsl("#cdbb8f") }),
		Underlined({ fg = hsl("#8ec3d0"), gui = "underline" }),
		Error({ fg = hsl("#ff6c6b"), bg = hsl("#2b1d1d") }),
		Todo({ fg = hsl("#ffffff"), bg = hsl("#a37050"), gui = "bold" }),
		CursorLine({ bg = hsl("#2b2b2a") }),
		Visual({ bg = hsl("#3a3a38") }),
		LineNr({ fg = hsl("#5b5b5b") }),
		CursorLineNr({ fg = hsl("#c9b480"), gui = "bold" }),
		Pmenu({ fg = hsl("#d2c6b0"), bg = hsl("#2b2b29") }),
		PmenuSel({ fg = hsl("#1e1e1d"), bg = hsl("#c9b480"), gui = "bold" }),
		StatusLine({ fg = hsl("#e0d7c3"), bg = hsl("#2c2c2b") }),
		StatusLineNC({ fg = hsl("#7a7a7a"), bg = hsl("#232322") }),
		VertSplit({ fg = hsl("#3a3a38") }),
		Directory({ fg = hsl("#8fc1a9"), gui = "bold" }),
		DiffAdd({ bg = hsl("#253626") }),
		DiffChange({ bg = hsl("#2e2e24") }),
		DiffDelete({ bg = hsl("#331e1e") }),
		MatchParen({ bg = hsl("#3d3d3a"), gui = "bold" }),
		Search({ fg = hsl("#1e1e1d"), bg = hsl("#d2c6b0"), gui = "bold" }),
	}
end)
