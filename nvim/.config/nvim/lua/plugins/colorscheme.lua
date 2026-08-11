return {
  {
    "craftzdog/solarized-osaka.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require("solarized-osaka").setup({
        on_highlights = function(hl, c)
          hl.DiagnosticUnderlineError = { undercurl = true, sp = c.error }
          hl.DiagnosticUnderlineWarn = { undercurl = true, sp = c.warning }
          hl.DiagnosticUnderlineInfo = { undercurl = true, sp = c.info }
          hl.DiagnosticUnderlineHint = { undercurl = true, sp = c.hint }
        end,
      })
      vim.cmd.colorscheme("solarized-osaka")
    end,
  },
}