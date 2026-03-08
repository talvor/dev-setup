return {
  "nvim-neotest/neotest",
  optional = true,
  dependencies = {
    "codymikol/neotest-kotlin",
  },
  opts = {
    adapters = {
      ["neotest-kotlin"] = {},
    },
  },
}
