return {
  {
    "akinsho/flutter-tools.nvim",
    ft = "dart",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "stevearc/dressing.nvim",
    },
    config = function()
      local flutter_tools = require("flutter-tools")

      flutter_tools.setup({
        ui = {
          border = "rounded",
          notification_style = "native",
        },
        decorations = {
          statusline = {
            app_version = true,
            device = true,
            project_config = false,
          },
        },
        debugger = {
          enabled = true,
          exception_breakpoints = {},
          evaluate_to_string_in_debug_views = true,
        },
        widget_guides = {
          enabled = true,
        },
        closing_tags = {
          highlight = "Comment",
          prefix = "// ",
          priority = 10,
          enabled = true,
        },
        dev_log = {
          enabled = true,
          open_cmd = "15split",
          focus_on_open = false,
        },
        dev_tools = {
          autostart = false,
          auto_open_browser = false,
        },
        outline = {
          open_cmd = "30vnew",
          auto_open = false,
        },
        lsp = {
          settings = {
            showTodos = true,
            completeFunctionCalls = true,
            renameFilesWithClasses = "prompt",
            enableSnippets = true,
            updateImportsOnRename = true,
          },
        },
      })

      local function apply_project_config()
        -- Hors projet Flutter : ne rien faire (évite la cascade
        -- setup_project -> LazyVim lsp refresh -> Mason install au démarrage).
        local ok_root, root = pcall(vim.fs.root, 0, "pubspec.yaml")
        if not ok_root or not root then
          return
        end
        local defines = vim.fs.joinpath(root, "dart_defines.json")
        if vim.uv.fs_stat(defines) then
          pcall(flutter_tools.setup_project, {
            {
              name = "project (dart_defines.json)",
              dart_define_from_file = "dart_defines.json",
            },
          })
        else
          pcall(flutter_tools.setup_project, {})
        end
      end

      local group = vim.api.nvim_create_augroup("MulediFlutterProjectConfig", { clear = true })
      vim.api.nvim_create_autocmd({ "LspAttach", "BufEnter" }, {
        group = group,
        pattern = "*.dart",
        callback = function()
          vim.schedule(apply_project_config)
        end,
      })
      apply_project_config()

      local map = vim.keymap.set
      local opts = { desc = "Flutter", silent = true }

      map("n", "<leader>Fs", "<cmd>FlutterRun<CR>", vim.tbl_extend("force", opts, { desc = "Flutter: Run" }))
      map("n", "<leader>Fr", "<cmd>FlutterReload<CR>", vim.tbl_extend("force", opts, { desc = "Flutter: Reload" }))
      map("n", "<leader>FR", "<cmd>FlutterRestart<CR>", vim.tbl_extend("force", opts, { desc = "Flutter: Restart" }))
      map("n", "<leader>Fd", "<cmd>FlutterDevices<CR>", vim.tbl_extend("force", opts, { desc = "Flutter: Devices" }))
      map("n", "<leader>Fe", "<cmd>FlutterEmulators<CR>", vim.tbl_extend("force", opts, { desc = "Flutter: Emulators" }))
      map("n", "<leader>Fo", "<cmd>FlutterOutline<CR>", vim.tbl_extend("force", opts, { desc = "Flutter: Outline" }))
      map("n", "<leader>Fq", "<cmd>FlutterQuit<CR>", vim.tbl_extend("force", opts, { desc = "Flutter: Quit" }))
      map("n", "<leader>Fp", "<cmd>FlutterPubGet<CR>", vim.tbl_extend("force", opts, { desc = "Flutter: Pub Get" }))
      map("n", "<leader>Fc", "<cmd>FlutterCopyProfilerUrl<CR>", vim.tbl_extend("force", opts, { desc = "Flutter: Copy Profiler URL" }))
      map("n", "<leader>Fv", "<cmd>FlutterDevTools<CR>", vim.tbl_extend("force", opts, { desc = "Flutter: DevTools" }))
      map("n", "<leader>Fa", "<cmd>FlutterAnalyze<CR>", vim.tbl_extend("force", opts, { desc = "Flutter: Analyze" }))
    end,
  },
}
