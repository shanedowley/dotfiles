-- Web + Lua + C/C++ formatting via conform.nvim
return {
  {
    "stevearc/conform.nvim",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      local conform = require("conform")

      conform.setup({
        -- Keep previous languages you already used (Lua, C/C++)
        formatters_by_ft = {
          lua = { "stylua" },
          c   = { "clang_format" },
          cpp = { "clang_format" },

          -- Web stack: all handled by Prettier
          javascript         = { "prettier" },
          javascriptreact    = { "prettier" },
          typescript         = { "prettier" },
          typescriptreact    = { "prettier" },
          json               = { "prettier" },
          jsonc              = { "prettier" },
          html               = { "prettier" },
          css                = { "prettier" },
          scss               = { "prettier" },
          less               = { "prettier" },
          markdown           = { "prettier" },
          ["markdown.mdx"]   = { "prettier" },
          yaml               = { "prettier" },
          graphql            = { "prettier" },
        },

        -- Format on save for common text-ish files; you can expand this
        format_on_save = function(bufnr)
          local ft = vim.bo[bufnr].filetype
          local enable = vim.tbl_contains({
            "lua","c","cpp",
            "javascript","javascriptreact",
            "typescript","typescriptreact",
            "json","jsonc","html","css","scss","less",
            "markdown","markdown.mdx","yaml","graphql",
          }, ft)
          return enable and { lsp_fallback = true, timeout_ms = 2000 } or false
        end,
      })

      -- Use local project prettier when available
      conform.formatters.prettier = {
        prepend_args = {},
        -- prefer local node prettier if present
        prefer_local = "node_modules/.bin",
      }

      -- Handy keymap: format the current buffer
      vim.keymap.set("n", "<leader>lf", function()
        require("conform").format({ async = true, lsp_fallback = true })
      end, { desc = "Format: buffer" })
    end,
  },
}


