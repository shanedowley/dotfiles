# 🛠️ Neovim IDE Cheatsheet

Personalized Neovim IDE setup with leader menus, keymaps, snippets, and workflows.

---

## 🔑 Leader Menus

- **<leader>d** → Debug
- **<leader>f** → File
- **<leader>g** → Git
- **<leader>l** → LSP (with Lspsaga UI)
- **<leader>m** → Surround (quotes, (), {})
- **<leader>q** → Sessions
- **<leader>r** → Refactor
- **<leader>t** → Tests

---

## 🧭 Navigation

- `<leader><leader>c` → Hop to char
- `<leader><leader>w` → Hop to word
- `<leader><leader>l` → Hop to line

- `<leader>jc` → Jump to char
- `<leader>jw` → Jump to word
- `<leader>jl` → Jump to line
- `<leader>jp` → Jump by pattern

- `<leader>ha` → Hop anywhere
- `<leader>hb` → Hop word backward
- `<leader>hp` → Hop by pattern

---

## 🧪 Testing (neotest + gtest)

- `<leader>tt` → Run nearest test
- `<leader>tf` → Run tests in file
- `<leader>to` → Open test output
- `<leader>ts` → Toggle summary panel

---

## 🪲 Debugging (DAP + DAP-UI)

- `<leader>db` → Toggle breakpoint
- `<leader>dc` → Continue
- `<leader>di` → Step into
- `<leader>do` → Step over
- `<leader>dO` → Step out
- `<leader>dr` → REPL toggle
- `<leader>du` → Toggle DAP UI

---

## 💻 LSP (via Lspsaga)

- `<leader>lh` → Hover (Saga)
- `<leader>lf` → Finder (Defs/Refs)
- `<leader>lp` → Peek Definition
- `<leader>lP` → Peek Type Definition
- `<leader>li` → Find Implementations
- `<leader>lr` → Rename Symbol (Saga)
- `<leader>la` → Code Action (Saga)
- `<leader>ld` → Buffer Diagnostics (Saga)
- `<leader>lD` → Workspace Diagnostics (Saga)
- `<leader>ls` → Show Diagnostics (buffer)
- `<leader>lj` → Next Diagnostic
- `<leader>lk` → Prev Diagnostic
- `<leader>lo` → Symbols Outline

---

## 📝 Snippets (LuaSnip + cmp)

- `cl` → expands to `console.log("")` (JS)
- `testblock` → expands to Jest `test("…")` block
- `gtest` (C++) → expands to GoogleTest boilerplate

---

## 🎨 Surround (nvim-surround)

- `ysiw"` → surround word with quotes
- `ysiw(` → surround word with parentheses
- `ysiw{` → surround word with braces
- `yss"` → surround entire line with quotes

- `<leader>mq` → surround word with quotes
- `<leader>mp` → surround word with parentheses
- `<leader>mb` → surround word with braces

---

## 💾 Sessions (persistence.nvim)

- `<leader>qs` → Save session
- `<leader>ql` → Load last session (auto reopens NvimTree)
- `<leader>qd` → Disable persistence

---

📌 Keep this file in your `dotfiles` repo (`~/dotfiles/nvim-cheatsheet.md`) for quick reference.
