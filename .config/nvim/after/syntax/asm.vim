" Extra Z80 mnemonics layered on top of asm Treesitter
if exists("b:current_syntax")
  syn keyword z80Opcode LD JP JR CALL RET PUSH POP INC DEC ADD ADC SBC SUB AND OR XOR CP NOP HALT EI DI RST
  syn keyword z80Register AF BC DE HL IX IY SP PC
  syn keyword z80Flag Z NZ C NC P PE PO M
  syn keyword z80Directive DB DW ORG EQU END
  hi def link z80Opcode Keyword
  hi def link z80Register Identifier
  hi def link z80Flag Constant
  hi def link z80Directive PreProc
endif
