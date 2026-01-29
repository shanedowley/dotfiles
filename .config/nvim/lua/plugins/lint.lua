-- Fast linting with eslint_d for JS/TS/React via nvim-lint
return {
  {
    "mfussenegger/nvim-lint",
    event = { "BufReadPost", "BufNewFile", "InsertLeave" },
    config = function()
      local lint = require("lint")

      -- Only run eslint_d when a project has an ESLint config
      local function has_eslint_config(root)
        local markers = {
          ".eslintrc", ".eslintrc.js", ".eslintrc.cjs", ".eslintrc.json",
          ".eslintrc.yaml", ".eslintrc.yml",
          "eslint.config.js", "eslint.config.cjs", "eslint.config.mjs", "eslint.config.ts",
          "package.json",
        }
        local found = vim.fs.find(markers, { upward = true, path = root, stop = vim.loop.os_homedir() })
        if #found == 0 then return false end
        -- if package.json exists, ensure it actually has "eslintConfig" (optional extra check)
        for _, p in ipairs(found) do
          if p:match("package%.json$") then
            local ok, pkg = pcall(vim.fn.json_decode, table.concat(vim.fn.readfile(p), "\n"))
            if ok and pkg and pkg.eslintConfig then return true end
          else
            return true
          end
        end
        return false
      end

      -- Configure available linters
      lint.linters_by_ft = {
        -- Only attach eslint_d when config present
        javascript = { "eslint_d" },
        javascriptreact = { "eslint_d" },
        typescript = { "eslint_d" },
        typescriptreact = { "eslint_d" },
        -- you can add others (e.g., "ruby" = rubocop) later
      }

      -- Wrap try_lint to conditionally run eslint_d
      local function try_eslint()
        local ft = vim.bo.filetype
        if ft ~= "javascript" and ft ~= "javascriptreact" and ft ~= "typescript" and ft ~= "typescriptreact" then
          lint.try_lint() -- other filetypes (if configured)
          return
        end
        local root = vim.fn.getcwd()
        if has_eslint_config(root) then
          lint.try_lint("eslint_d")
        else
          -- no config; skip silently
        end
      end

      -- Run linting on key events
      local aug = vim.api.nvim_create_augroup("LintAuto", { clear = true })
      vim.api.nvim_create_autocmd({ "BufWritePost", "InsertLeave", "TextChanged" }, {
        group = aug,
        callback = function()
          -- Debounce a little after text change
          vim.defer_fn(try_eslint, 150)
        end,
      })

      -- Keymaps
      vim.keymap.set("n", "<leader>ll", function()
        try_eslint()
        vim.notify("Lint: ran", vim.log.levels.INFO, { title = "nvim-lint" })
      end, { desc = "Lint: run eslint_d" })

      vim.keymap.set("n", "<leader>lo", function()
        vim.cmd("lopen")
      end, { desc = "Lint: open location list" })

      -- optional: close loclist if empty
      vim.api.nvim_create_autocmd("User", {
        pattern = "LintFinished",
        group = aug,
        callback = function()
          if #vim.fn.getloclist(0) == 0 then
            -- vim.cmd("lclose")
          end
        end,
      })
    end,
  },
}


