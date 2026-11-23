return {
  -- L'extra LazyVim lang.python gère déjà : pyright (défaut), ruff,
  -- debugpy via setup("debugpy-adapter"). On ne surcharge que neotest.
  -- Tests Python via neotest (même pattern que test.lua vitest/jest).
  {
    "nvim-neotest/neotest",
    optional = true,
    dependencies = {
      "nvim-neotest/neotest-python",
    },
    opts = {
      adapters = {
        ["neotest-python"] = {
          runner = "pytest",
          dap = { justMyCode = false },
        },
      },
    },
  },
}
