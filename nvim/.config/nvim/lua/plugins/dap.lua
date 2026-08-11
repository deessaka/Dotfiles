return {
  -- Adaptation DAP par-dessus l'extra LazyVim dap.core (nvim-dap + nvim-dap-ui)
  {
    "mfussenegger/nvim-dap",
    dependencies = { "nvim-neotest/nvim-nio" },
    config = function(_, opts)
      local dap = require("dap")

      -- Node/TS : vscode-js-debug
      dap.adapters["pwa-node"] = {
        type = "server",
        host = "localhost",
        port = "${port}",
        executable = {
          command = "node",
          args = {
            vim.fn.stdpath("data")
              .. "/mason/packages/js-debug-adapter/js-debug/src/dapDebugServer.js",
            "${port}",
          },
        },
      }
      dap.configurations.typescript = {
        {
          name = "Launch npm run dev",
          type = "pwa-node",
          request = "launch",
          cwd = "${workspaceFolder}",
          runtimeExecutable = "npm",
          runtimeArgs = { "run", "dev" },
        },
        {
          name = "Attach to process (node)",
          type = "pwa-node",
          request = "attach",
          processId = require("dap.utils").pick_process,
        },
      }
      dap.configurations.javascriptreact = vim.deepcopy(dap.configurations.typescript)
      dap.configurations.typescriptreact = vim.deepcopy(dap.configurations.typescript)

      -- Go : delve
      dap.adapters.delve = {
        type = "server",
        port = "${port}",
        executable = { command = "dlv", args = { "dap", "-l", "127.0.0.1:${port}" } },
      }
      dap.configurations.go = {
        {
          type = "delve",
          name = "Debug (Go)",
          request = "launch",
          program = "${workspaceFolder}",
        },
      }

      -- Flutter/Dart : dart DAP
      dap.adapters.dart = {
        type = "executable",
        command = "dart",
        args = { "debug_adapter" },
      }
      dap.configurations.dart = {
        {
          type = "dart",
          request = "launch",
          name = "Run flutter main.dart",
          program = "${workspaceFolder}/lib/main.dart",
          cwd = "${workspaceFolder}",
        },
      }
    end,
  },
}