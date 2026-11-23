return {
  -- Completion inline via Copilot
  {
    "zbirenbaum/copilot.lua",
    event = "InsertEnter",
    opts = {
      suggestion = {
        enabled = true,
        -- auto_trigger off : le churn réseau/LSP à chaque frappe gelait nvim
        auto_trigger = false,
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
  -- server.start = false : ne JAMAIS spawner de serveur (opencode --port) dans
  -- nvim (nil ne surcharge pas le défaut via tbl_deep_extend ; false aborte la
  -- découverte au lieu de lancer un vsplit `opencode --port`).
  -- Le TUI externe doit tourner avec `opencode --port 5789` ; le plugin s'y
  -- attache via la découverte (pgrep/lsof + chevauchement de cwd). Deux agents
  -- qui écrivent les mêmes fichiers = conflits.
  {
    "nickjvandyke/opencode.nvim",
    event = { "VeryLazy" },
    init = function()
      vim.g.opencode_opts = {
        server = {
          start = false,
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

}