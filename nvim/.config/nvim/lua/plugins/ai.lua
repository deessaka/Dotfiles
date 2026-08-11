return {
  -- Completion inline via Copilot
  {
    "zbirenbaum/copilot.lua",
    event = "InsertEnter",
    opts = {
      suggestion = {
        enabled = true,
        auto_trigger = true,
        keymap = { accept = "<M-l>" },
      },
      filetypes = {
        markdown = true,
        help = true,
      },
    },
  },

  -- Agent opencode : agent intégré (ADR-0002).
  -- Pas de setup() dans ce plugin : config via vim.g.opencode_opts + keymaps.
  {
    "nickjvandyke/opencode.nvim",
    event = { "VeryLazy" },
    init = function()
      vim.g.opencode_opts = {
        -- optionnel : réutilise le serveur opencode déjà lancé
        server = {
          start = { "opencode", "--port", "5789" },
        },
      }
    end,
    keys = {
      { "<leader>ai", function() require("opencode").select() end, desc = "OpenCode: menu" },
      { "<leader>aq", function() require("opencode").ask("@this: ") end, mode = { "n", "x" }, desc = "OpenCode: ask" },
      { "go", function() return require("opencode").operator("@this ") end, expr = true, desc = "OpenCode: append range (operator)" },
      { "goo", function() return require("opencode").operator("@this ") .. "_" end, expr = true, desc = "OpenCode: append line" },
    },
  },

  -- Assistant conversationnel : avante.nvim, provider Gemini via OAuth ACP (ADR-0002)
  {
    "yetone/avante.nvim",
    event = "VeryLazy",
    build = "make", -- utilise le binaire pré-buildé via curl/tar (pas besoin de cargo)
    version = false,
    opts = {
      provider = "gemini",
      mode = "agentic",
      file_selector = {
        provider = "telescope",
      },
      hints = { enabled = true },
      windows = {
        width = 30,
        sidebar_header = {
          align = "center",
          rounded = true,
        },
      },
    },
    keys = {
      { "<leader>aa", "<cmd>Avante<CR>", desc = "Avante assistant" },
      { "<leader>ar", "<cmd>AvanteRefresh<CR>", desc = "Avante refresh" },
    },
  },
}