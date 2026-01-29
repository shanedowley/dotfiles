-- ~/.config/nvim/lua/plugins/asm.lua
-- Z80 and assembly syntax support
return {
	{
		"samsaga2/vim-z80", -- archived Z80 syntax highlighting
		ft = { "z80", "asm" }, -- activate only for these filetypes
	},
}
