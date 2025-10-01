-- ~/.config/nvim/lua/plugins/debug_js.lua
-- JavaScript/TypeScript debugging via js-debug (Node + Chrome)

return {
  {
    -- Load this whole stack eagerly so configs always register
    lazy = false,

    -- Core DAP + UI
    "mfussenegger/nvim-dap",
    dependencies = {
      "rcarriga/nvim-dap-ui",
      "nvim-neotest/nvim-nio",

      -- vscode-js-debug bridge for nvim-dap
      {
        "mxsdev/nvim-dap-vscode-js",
        dependencies = {
          {
            "microsoft/vscode-js-debug",
            version = "1.x",
            build = "npm ci && npm run compile",
          },
        },
      },
    },

    config = function()
      local dap = require("dap")
      local dapui = require("dapui")

      -- UI wiring
      dapui.setup()
      dap.listeners.after.event_initialized["dapui_config"] = function() dapui.open() end
      dap.listeners.before.event_terminated["dapui_config"] = function() dapui.close() end
      dap.listeners.before.event_exited["dapui_config"] = function() dapui.close() end

      -- Explicit path where Lazy clones js-debug
      local debugger_path = vim.fn.stdpath("data") .. "/lazy/vscode-js-debug"
      require("dap-vscode-js").setup({
        node_path = "node",
        debugger_path = debugger_path,
        adapters = { "pwa-node", "pwa-chrome" },
      })

      -- Helper to ensure a config exists for a given filetype
      local function ensure(ft, cfg)
        dap.configurations[ft] = dap.configurations[ft] or {}
        table.insert(dap.configurations[ft], cfg)
      end

      -- Configs
      local node_launch = {
        name = "Node: Launch current file",
        type = "pwa-node",
        request = "launch",
        program = "${file}",
        cwd = "${workspaceFolder}",
        runtimeExecutable = "node",
        console = "integratedTerminal",
        sourceMaps = true,
      }

      local node_attach = {
        name = "Node: Attach",
        type = "pwa-node",
        request = "attach",
        processId = require("dap.utils").pick_process,
        cwd = "${workspaceFolder}",
      }

      local chrome_attach = {
        name = "Chrome: Attach to localhost",
        type = "pwa-chrome",
        request = "attach",
        url = "http://localhost:5173", -- change if your dev server differs
        webRoot = "${workspaceFolder}",
        sourceMaps = true,
      }

      for _, ft in ipairs({ "javascript", "typescript", "javascriptreact", "typescriptreact" }) do
        ensure(ft, node_launch)
        ensure(ft, node_attach)
        ensure(ft, chrome_attach)
      end

      -- (Optional) basic keymaps if you don’t already have them
      local map = function(lhs, rhs, desc) vim.keymap.set("n", lhs, rhs, { desc = "DAP: " .. desc }) end
      map("<F5>", dap.continue, "Continue/Start")
      map("<F10>", dap.step_over, "Step Over")
      map("<F11>", dap.step_into, "Step Into")
      map("<S-F11>", dap.step_out, "Step Out")
      map("<leader>db", dap.toggle_breakpoint, "Toggle Breakpoint")
      map("<leader>dB", function() dap.set_breakpoint(vim.fn.input("Breakpoint condition: ")) end, "Conditional BP")
      map("<leader>du", dapui.toggle, "Toggle UI")
      map("<leader>dr", dap.repl.toggle, "Toggle REPL")
    end,
  },
}


