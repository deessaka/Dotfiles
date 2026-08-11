return {
  {
    "kristijanhusak/vim-dadbod-ui",
    dependencies = {
      { "tpope/vim-dadbod", lazy = true },
      {
        "kristijanhusak/vim-dadbod-completion",
        ft = { "sql", "mysql", "plsql" },
        lazy = true,
      },
    },
    cmd = { "DBUI", "DBUIToggle" },
    keys = {
      { "<leader>db", "<cmd>DBUIToggle<cr>", desc = "Toggle database browser" },
      { "<leader>dq", "<cmd>DBUI<cr>", desc = "Open database browser" },
    },
    config = function()
      vim.g.db_ui_use_nerd_fonts = 1
      vim.g.db_ui_auto_execute_on_open = 1
      -- Connexion par défaut : conteneur Postgres Docker (ADR-0003)
      -- Override via :DBUIAddConnection (ex `postgresql://user:pass@localhost:5432/db`)
    end,
  },
}