-- Local mission dashboard, initialized alongside the existing Sidekick plugin.
return {
  {
    "folke/sidekick.nvim",
    init = function()
      require("mission_dashboard").setup()
    end,
    keys = {
      { "<leader>am", "<cmd>TeamMissionsToggle<cr>", desc = "Missions: panneau" },
    },
  },
}
