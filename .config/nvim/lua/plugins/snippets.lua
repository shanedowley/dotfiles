-- ~/.config/nvim/lua/plugins/snippets.lua
-- Snippet engine + snippet definitions

return {
  {
    "L3MON4D3/LuaSnip",
    lazy = false, -- load immediately (so snippets are always available)
    dependencies = {
      "rafamadriz/friendly-snippets", -- optional: prebuilt snippets
    },
    config = function()
      local luasnip = require("luasnip")

      -- Load snippets from ~/.config/nvim/lua/snippets/{filetype}.lua
      -- Eager load (immediate), avoids lazy-load issues
      require("luasnip.loaders.from_lua").load({
        paths = vim.fn.stdpath("config") .. "/lua/snippets",
      })

      -- Optionally also load VSCode-format snippets
      require("luasnip.loaders.from_vscode").load()

      -- Keymaps for snippet expansion / navigation
      vim.keymap.set({ "i", "s" }, "<Tab>", function()
        if luasnip.expand_or_jumpable() then
          return "<Plug>luasnip-expand-or-jump"
        else
          return "<Tab>"
        end
      end, { expr = true, silent = true })

      vim.keymap.set({ "i", "s" }, "<S-Tab>", function()
        if luasnip.jumpable(-1) then
          return "<Plug>luasnip-jump-prev"
        else
          return "<S-Tab>"
        end
      end, { expr = true, silent = true })

      -- Reload snippets without restarting Neovim
      vim.keymap.set("n", "<leader>rs", function()
        luasnip.cleanup()
        require("luasnip.loaders.from_lua").load({
          paths = vim.fn.stdpath("config") .. "/lua/snippets",
        })
        print("[LuaSnip] Reloaded snippets")
      end, { desc = "Reload snippets" })
    end,
  },
}


