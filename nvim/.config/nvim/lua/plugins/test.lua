return {
  -- Adaptateurs neotest supplémentaires (vitest + jest).
  -- Le neotest de base et ses keymaps viennent de l'extra test.core ;
  -- l'adaptateur Go vient de l'extra lang.go (neotest-golang).
  {
    "nvim-neotest/neotest",
    optional = true,
    dependencies = {
      "marilari88/neotest-vitest",
      "haydenmeade/neotest-jest",
    },
    opts = {
      adapters = {
        ["neotest-vitest"] = {},
        ["neotest-jest"] = {},
      },
    },
  },
}