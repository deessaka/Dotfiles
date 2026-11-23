return {
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "nvim-neotest/nvim-nio",
      {
        "AkisArou/nvim-dap-react-native",
        build = "npm ci",
      },
    },
    config = function(_, opts)
      local dap = require("dap")

      -- Node/TS : vscode-js-debug (pwa-node)
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

      -- React Native : Hermes CDP adapter (pwa-node based)
      dap.adapters["reactnativedirect"] = require("dap-react-native").create_adapter(
        dap.adapters["pwa-node"]
      )
      for _, ft in ipairs({ "javascript", "typescript", "javascriptreact", "typescriptreact" }) do
        dap.configurations[ft] = dap.configurations[ft] or {}
        table.insert(dap.configurations[ft], {
          type = "reactnativedirect",
          request = "attach",
          name = "RN: Attach Hermes",
          cwd = "${workspaceFolder}",
          address = "127.0.0.1",
          port = 8081,
          sourceMaps = true,
          sourceMapPathOverrides = {
            ["/[metro-project]/*"] = "${workspaceFolder}/*",
          },
          skipFiles = {
            "<node_internals>/**",
            "node_modules/**",
            "**/node_modules/undici/**",
            "**/node_modules/typescript/**",
            "**/node_modules/@expo/**",
            "**/*.bundle.js",
            "**/*.min.js",
          },
        })
      end

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
    end,
  },
}
